#define Point OSXPoint
#define Rect OSXRect

#import "screen-cocoa.h"

#undef Point
#undef Rect

#include "u.h"
#include "libc.h"
#include "kern/mem.h"
#include "kern/dat.h"
#include "error.h"
#include "user.h"

#define Image IMAGE
#include <draw.h>
#include <memdraw.h>
#include <keyboard.h>

#include <cursor.h>
#include "kern/screen.h"

#include "osx-keycodes.h"
#include "drawterm.h"
#include "devdraw.h"
#include "bigarrow.h"
#include "docpng.h"

extern int		collecting;
extern int		kbdputc(Queue*, int);
extern ulong	msec(void);

extern Cursorinfo cursor;

extern P9AppDelegate *_appdelegate;

#define LOG	if(0)NSLog

int usegestures = 0;
int useliveresizing = 0;
int useoldfullscreen = 0;
int usebigarrow = 1;

int alting;

Memimage	*gscreen;
Screeninfo	screeninfo;

NSUInteger Winstyle;

#define WIN	win.ofs[win.isofs]

struct
{
	NSWindow	*ofs[2];	/* ofs[1] for old fullscreen; ofs[0] else */
	int			isofs;
	int			isnfs;
	NSView		*content;
	NSBitmapImageRep	*img;
	int			needimg;
	int			deferflush;
	NSCursor		*cursor;
	Lock 		lk;
} win;

struct
{
	NSCursor	*bigarrow;
	NSUInteger	kbuttons;
	NSUInteger	mbuttons;
	NSPoint	mpos;
	int		mscroll;
	int		willactivate;
} in;

void initcpu(void);
void	topwin(void);
void kicklabel(char *label);

static void flushimg(NSRect);
static void autoflushwin(int);
static void flushwin(void);
static void followzoombutton(NSRect);
static void getmousepos(void);
static void makeicon(void);
static void makemenu(void);
static void makewin(NSSize*);
static void sendmouse(void);
static void kicklabel0(char*);
static void setcursor0(NSCursor*);
static void togglefs(void);
static void acceptresizing(int);

static NSCursor* makecursor(Cursor*);

NSDictionary*
dtdefaults()
{
	NSUserDefaults *defaults;
	NSDictionary *dict;
	defaults = [NSUserDefaults standardUserDefaults];
	dict = [defaults persistentDomainForName:@"com.bell-labs.plan9.drawterm"];
	return dict;
}

@implementation P9AppDelegate

@synthesize arrowCursor = _arrowCursor;

+ (void)callflushimg:(NSValue*)v{ flushimg([v rectValue]);}
+ (void)callflushwin:(id)arg{ flushwin();}
+ (void)callmakewin:(NSValue*)v{ makewin([v pointerValue]);}
+ (void)callsetcursor0:(NSCursor*)c { setcursor0(c); }
+ (void)callkicklabel0:(NSValue*)v{ kicklabel0([v pointerValue]);}

- (void)calltogglefs:(id)arg{ togglefs();}

- (void)applicationDidFinishLaunching:(id)arg
{
	NSProcessInfo *pinfo;
	NSDictionary *dict;

	pinfo = [NSProcessInfo processInfo];
	[pinfo enableSuddenTermination];

	/* default winstyle */
	Winstyle = NSTitledWindowMask
		 | NSClosableWindowMask
		 | NSMiniaturizableWindowMask
		 | NSResizableWindowMask;

	dict = dtdefaults();
	if(dict != nil) {
		id obj = [dict objectForKey:@"TitledWindow"];
		if(obj != nil && ![obj boolValue])
			Winstyle = NSMiniaturizableWindowMask | NSResizableWindowMask;
	}

	makeicon();
	makemenu();
	in.bigarrow = makecursor(&arrow);

	initcpu();
}

- (void)applicationWillTerminate:(NSNotification *)note
{
/* any shutdown code should be placed here */
}

- (void)windowDidBecomeKey:(id)arg
{
	if(win.isnfs)
		[win.content setHidden:NO];
	getmousepos();
	sendmouse();
}

- (void)windowDidResignKey:(NSNotification *)notification
{
	if(win.isnfs)
		[win.content setHidden:YES];
}

- (void)windowDidResize:(id)arg
{
	getmousepos();
	sendmouse();
}

- (void)windowWillStartLiveResize:(id)arg
{
	if(useliveresizing == 0)
		[win.content setHidden:YES];
}

- (void)windowDidEndLiveResize:(id)arg
{
	if(useliveresizing == 0)
		[win.content setHidden:NO];
}

- (void)windowDidChangeScreen:(id)arg
{
	[win.ofs[1] setFrame:[[WIN screen] frame] display:YES];
}

- (BOOL)windowShouldZoom:(id)arg toFrame:(NSRect)r
{
	followzoombutton(r);
	return YES;
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(id)arg
{
	return YES;
}

- (void)applicationDidBecomeActive:(id)arg{ in.willactivate = 0;}
- (void)windowWillEnterFullScreen:(id)arg{ acceptresizing(1);}
- (void)windowDidEnterFullScreen:(id)arg{ win.isnfs = 1;}
- (void)windowWillExitFullScreen:(id)arg{ win.isnfs = 0;}
- (void)windowDidExitFullScreen:(id)arg
{
	NSButton *b;
	b = [WIN standardWindowButton:NSWindowMiniaturizeButton];

	if([b isEnabled] == 0)
		[b setEnabled:YES];
}
- (void)windowWillClose:(id)arg
{
	autoflushwin(0);	/* can crash otherwise */
}


- (NSApplicationPresentationOptions)window:(NSWindow *)window
	willUseFullScreenPresentationOptions:(NSApplicationPresentationOptions)proposedOptions
{
	// support full screen for this window (required)
	NSApplicationPresentationOptions ops = NSApplicationPresentationFullScreen;
			  
	if (floor(NSAppKitVersionNumber) >= NSAppKitVersionNumber10_7) {
		ops = ops |
			  NSApplicationPresentationHideDock |
			  NSApplicationPresentationAutoHideMenuBar;
	}
	return ops;
}
@end


static Memimage* initimg(void);

uchar *
attachscreen(Rectangle *r, ulong *chan, int *depth, int *width, int *softscreen, void **X)
{
	if(gscreen == nil){
		screeninit();
		if(gscreen == nil)
			panic("cannot create OS X screen");
	}

	if(X != nil)
		*X = gscreen->X;

	LOG(@"attachscreen %d %d %d %d",
		gscreen->r.min.x, gscreen->r.min.y, Dx(gscreen->r), Dy(gscreen->r));
	*r = gscreen->r;
	*chan = gscreen->chan;
	*depth = gscreen->depth;
	*width = gscreen->width;
	*softscreen = 1;

	return gscreen->data->bdata;
}

@interface appwin : NSWindow @end
@interface contentview : NSView @end

@implementation appwin
- (NSTimeInterval)animationResizeTime:(NSRect)r
{
	return 0;
}
- (BOOL)canBecomeKeyWindow
{
	return YES;	/* else no keyboard for old fullscreen */
}
- (void)makeKeyAndOrderFront:(id)arg
{
	LOG(@"makeKeyAndOrderFront");
	autoflushwin(1);
	[win.content setHidden:NO];
	[super makeKeyAndOrderFront:arg];
}
- (void)miniaturize:(id)arg
{
	[super miniaturize:arg];
	[NSApp hide:nil];

	[win.content setHidden:YES];
	autoflushwin(0);
}
- (void)deminiaturize:(id)arg
{
	autoflushwin(1);
	[win.content setHidden:NO];
	[super deminiaturize:arg];
}
- (void)zoom:(id)sender
{
	NSUInteger old, style;

	[super zoom:sender];

	old = [WIN styleMask];

	if([self isZoomed])
		style = Winstyle & ~NSResizableWindowMask;
	else
		style = Winstyle;

	if(style != old)
		[WIN setStyleMask:style];
}
@end

double
min(double a, double b)
{
	return a<b? a : b;
}

static void
makewin(NSSize *s)
{
	NSRect r, sr;
	NSWindow *w;
	Rectangle wr;
	int i, set;

	sr = [[NSScreen mainScreen] frame];
	r = [[NSScreen mainScreen] visibleFrame];

	if(s != NULL){
		wr = Rect(0, 0, (int)s->width, (int)s->height);
		set = 0;
	}else{
		wr = Rect(0, 0, (int)sr.size.width*2/3, (int)sr.size.height*2/3);
		set = 0;
	}

	LOG(@"makewin %d %d", Dx(wr), Dy(wr));
	r.origin.x = wr.min.x;
	r.origin.y = sr.size.height-wr.max.y;	/* winsize is top-left-based */
	r.size.width = min(Dx(wr), r.size.width);
	r.size.height = min(Dy(wr), r.size.height);
	r = [NSWindow contentRectForFrameRect:r styleMask:Winstyle];

	w = [[appwin alloc] initWithContentRect:r
								  styleMask:Winstyle
									backing:NSBackingStoreBuffered
									  defer:NO];

	if(!set)
		[w center];
	if (floor(NSAppKitVersionNumber) >= NSAppKitVersionNumber10_7) {
		[w setCollectionBehavior:NSWindowCollectionBehaviorFullScreenPrimary];
	}
	[w setMinSize:NSMakeSize(320,200)];
//	[w registerForDraggedTypes:
//		[NSArray arrayWithObjects:  NSFilenamesPboardType, nil]];

	win.ofs[0] = w;
	win.ofs[1] = [[appwin alloc] initWithContentRect:sr
										   styleMask:NSBorderlessWindowMask
											 backing:NSBackingStoreBuffered
											   defer:YES];
	for(i=0; i<2; i++){
		[win.ofs[i] setAcceptsMouseMovedEvents:YES];
		[win.ofs[i] setDelegate:_appdelegate];
		[win.ofs[i] setDisplaysWhenScreenProfileChanges:NO];
		[win.ofs[i] setPreservesContentDuringLiveResize:YES];
	}
	win.isofs = 0;
	win.content = [[contentview alloc] initWithFrame:r];
	[WIN setContentView:win.content];

	topwin();
}

static Memimage*
initimg(void)
{
	Memimage *i;
	Rectangle r;
	NSRect bounds;

	bounds = [win.content bounds];
	LOG(@"initimg %.0f %.0f", NSWidth(bounds), NSHeight(bounds));

	r = Rect(0, 0, (int)NSWidth(bounds), (int)NSHeight(bounds));
	i = allocmemimage(r, XBGR32);
	if(i == nil)
		panic("allocmemimage: %r");
	if(i->data == nil)
		panic("i->data == nil");

	win.img = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:&i->data->bdata
			pixelsWide:Dx(r)
			pixelsHigh:Dy(r)
			bitsPerSample:8
			samplesPerPixel:3
			hasAlpha:NO
			isPlanar:NO
			colorSpaceName:NSDeviceRGBColorSpace
			bytesPerRow:bytesperline(r, 32)
			bitsPerPixel:32];

	i->data->allocd = 0;	/* win.img now owns the Memdata */

	return i;
}

static void
resizeimg()
{
	Memimage *m;

	LOG(@"resizeimg");
	if(win.img == nil)
		return;

	lock(&win.lk);
	[win.content setHidden:YES];		/* prevent flushimg from drawing */
	m = gscreen;

	[win.img release];
	gscreen = initimg();

	termreplacescreenimage(gscreen);
	drawreplacescreenimage(gscreen);

	[win.content setHidden:NO];			/* reenable the flush */
	unlock(&win.lk);

	sendmouse();
}

static void
waitimg(int msec)
{
	NSDate *limit;
	int n;

	win.needimg = 1;
	win.deferflush = 0;

	n = 0;
	limit = [NSDate dateWithTimeIntervalSinceNow:msec/1000.0];
	do{
		[[NSRunLoop currentRunLoop] runMode:@"waiting image" beforeDate:limit];
		n++;
	}while(win.needimg && [(NSDate*)[NSDate date] compare:limit]<0);

	win.deferflush = win.needimg;

	LOG(@"waitimg %s (%d loop)", win.needimg?"defer":"ok", n);
}

void
flushmemscreen(Rectangle r)
{
	NSRect dr = NSMakeRect(r.min.x, r.min.y, Dx(r), Dy(r));
	LOG(@"flushmemscreen %d %d", Dx(r), Dy(r));

	/* sanity check.  Trips from the initial "terminal" */
    if (r.max.x < r.min.x || r.max.y < r.min.y) {
		LOG(@"  wa %d %d %d %d", r.max.x, r.min.x, r.max.y, r.min.y);
    	return;
    }

	if([win.content canDraw] == 0) {
		LOG(@"  win can't draw");
		return;
	}

	/* OS X no longer needs to draw from the main thread */
	if (floor(NSAppKitVersionNumber) < NSAppKitVersionNumber10_10) {
		[P9AppDelegate performSelectorOnMainThread:@selector(callflushimg:)
			withObject:[NSValue valueWithRect:dr]
			waitUntilDone:YES
			modes:[NSArray arrayWithObjects:
				NSRunLoopCommonModes,
				@"waiting image", nil]];
	} else {
		flushimg(dr);
	}
}

static void drawimg(NSRect, NSCompositingOperation);
static void drawresizehandle(void);

enum
{
	Pixel = 1,
	Barsize = 4*Pixel,
	Cornersize = 3*Pixel,
	Handlesize = 3*Barsize + 1*Pixel,
};

static void
flushimg(NSRect rect)
{
	NSRect dr, r;

	if([win.content lockFocusIfCanDraw] == NO){
		LOG(@"flushimg reject (%.0f, %.0f) can't draw", rect.size.width, rect.size.height);
		return;
	}

	if(win.needimg){
		/*
		if(!NSEqualSizes(rect.size, [win.img size])){
			LOG(@"flushimg reject (%.0f, %.0f) != (%.0f, %.0f)",
				rect.size.width, rect.size.height,
				[win.img size].width, [win.img size].height);
			[win.content unlockFocus];
			return;
		}*/
		win.needimg = 0;
	}else
		win.deferflush = 1;

	/*
	 * Unless we are inside "drawRect", we have to round
	 * the corners ourselves, if this is the custom.
	 * "NSCompositeSourceIn" can do that, but we don't
	 * apply it to the whole rectangle, because this
	 * slows down trackpad scrolling considerably in
	 * Acme.
	 */
	r = [win.content bounds];
	r.size.height -= Cornersize;
	dr = NSIntersectionRect(r, rect);
	drawimg(dr, NSCompositeCopy);

	r.origin.y = r.size.height;
	r.size = NSMakeSize(Cornersize, Cornersize);
	dr = NSIntersectionRect(r, rect);
	drawimg(dr, NSCompositeSourceIn);

	r.origin.x = [win.img size].width - Cornersize;
	dr = NSIntersectionRect(r, rect);
	drawimg(dr, NSCompositeSourceIn);

	r.size.width = r.origin.x - Cornersize;
	r.origin.x -= r.size.width;
	dr = NSIntersectionRect(r, rect);
	drawimg(dr, NSCompositeCopy);

	if (floor(NSAppKitVersionNumber) < NSAppKitVersionNumber10_7 && win.isofs==0){
		r.origin.x = [win.img size].width - Handlesize;
		r.origin.y = [win.img size].height - Handlesize;
		r.size = NSMakeSize(Handlesize, Handlesize);
		if(NSIntersectsRect(r, rect))
			drawresizehandle();
	}
	[win.content unlockFocus];
	LOG(@"flushimg ok %.0f %.0f", rect.size.width, rect.size.height);
}

static void
autoflushwin(int set)
{
	static NSTimer *t;

	if(set){
		if(t)
			return;
		/*
		 * We need "NSRunLoopCommonModes", otherwise the
		 * timer will not fire during live resizing.
		 */
		t = [NSTimer timerWithTimeInterval:0.033
				target:[P9AppDelegate class]
				selector:@selector(callflushwin:) userInfo:nil
				repeats:YES];
		[[NSRunLoop currentRunLoop] addTimer:t forMode:NSRunLoopCommonModes];
	}else{
		[t invalidate];
		t = nil;
		win.deferflush = 0;
	}
}

static void
flushwin(void)
{
	if(win.deferflush && win.needimg==0){
		[WIN flushWindow];
		win.deferflush = 0;
	}
}

static void
drawimg(NSRect dr, NSCompositingOperation op)
{
	CGContextRef c;
	CGImageRef i;
	NSRect sr;

	if(NSIsEmptyRect(dr))
		return;

	sr = [win.content convertRect:dr fromView:nil];

	i = CGImageCreateWithImageInRect([win.img CGImage], NSRectToCGRect(dr));
	c = [[WIN graphicsContext] graphicsPort];

	CGContextSaveGState(c);
	if(op == NSCompositeSourceIn)
		CGContextSetBlendMode(c, kCGBlendModeSourceIn);
	CGContextTranslateCTM(c, 0, [win.img size].height);
	CGContextScaleCTM(c, 1, -1);
	CGContextDrawImage(c, NSRectToCGRect(sr), i);
	CGContextRestoreGState(c);
	CGContextFlush(c);

	CGImageRelease(i);
}

static void
drawresizehandle(void)
{
	NSColor *color[Barsize];
	NSPoint a,b;
	Point c;
	int i,j;

	c = Pt((int)[win.img size].width, (int)[win.img size].height);

	[[WIN graphicsContext] setShouldAntialias:NO];

	color[0] = [NSColor clearColor];
	color[1] = [NSColor darkGrayColor];
	color[2] = [NSColor lightGrayColor];
	color[3] = [NSColor whiteColor];

	for(i=1; i+Barsize <= Handlesize; )
		for(j=0; j<Barsize; j++){
			[color[j] setStroke];
			i++;
			a = NSMakePoint(c.x-i, c.y-1);
			b = NSMakePoint(c.x-2, c.y+1-i);
			[NSBezierPath strokeLineFromPoint:a toPoint:b];
		}
}

static void getgesture(NSEvent*);
static void getkeyboard(NSEvent*);
static void getmouse(NSEvent*);
static void gettouch(NSEvent*, int);
static void updatecursor(void);

@implementation contentview
- (BOOL)preservesContentDuringLiveResize { return YES; }

/*
 * "drawRect" is called each time Cocoa needs an
 * image, and each time we call "display".  It is
 * preceded by background painting, and followed by
 * "flushWindow".
 */
- (void)drawRect:(NSRect)r
{
	static int first = 1;

	LOG(@"drawrect %.0f %.0f %.0f %.0f",
		r.origin.x, r.origin.y, r.size.width, r.size.height);

	if(first)
		first = 0;
	else
		resizeimg();

	/* build in a slight delay after the resize to catch up with drawing */
	if([WIN inLiveResize])
		waitimg(100);
	else
		waitimg(500);		
}

- (BOOL)isFlipped
{
	return YES;	/* to make the content's origin top left */
}
- (BOOL)acceptsFirstResponder
{
	return YES;	/* else no keyboard */
}
- (id)initWithFrame:(NSRect)r
{
	[super initWithFrame:r];
	[self setAcceptsTouchEvents:YES];
	[self setHidden:YES];		/* to avoid early "drawRect" call */
	return self;
}
- (void)setHidden:(BOOL)set
{
	if(!set)
		[WIN makeFirstResponder:self];	/* for keyboard focus */
	[super setHidden:set];
}
- (void)cursorUpdate:(NSEvent*)e{ updatecursor();}

- (void)mouseMoved:(NSEvent*)e{ getmouse(e);}
- (void)mouseDown:(NSEvent*)e{ getmouse(e);}
- (void)mouseDragged:(NSEvent*)e{ getmouse(e);}
- (void)mouseUp:(NSEvent*)e{ getmouse(e);}
- (void)otherMouseDown:(NSEvent*)e{ getmouse(e);}
- (void)otherMouseDragged:(NSEvent*)e{ getmouse(e);}
- (void)otherMouseUp:(NSEvent*)e{ getmouse(e);}
- (void)rightMouseDown:(NSEvent*)e{ getmouse(e);}
- (void)rightMouseDragged:(NSEvent*)e{ getmouse(e);}
- (void)rightMouseUp:(NSEvent*)e{ getmouse(e);}
- (void)scrollWheel:(NSEvent*)e{ getmouse(e);}

- (void)keyDown:(NSEvent*)e{ getkeyboard(e);}
- (void)flagsChanged:(NSEvent*)e{ getkeyboard(e);}

- (void)magnifyWithEvent:(NSEvent*)e{ getgesture(e);}

- (void)touchesBeganWithEvent:(NSEvent*)e
{
	gettouch(e, NSTouchPhaseBegan);
}
- (void)touchesMovedWithEvent:(NSEvent*)e
{
	gettouch(e, NSTouchPhaseMoved);
}
- (void)touchesEndedWithEvent:(NSEvent*)e
{
	gettouch(e, NSTouchPhaseEnded);
}
- (void)touchesCancelledWithEvent:(NSEvent*)e
{
	gettouch(e, NSTouchPhaseCancelled);
}
@end

#pragma clang diagnostic ignored "-Wgnu-designator"

static int keycvt[] =
{
	[QZ_IBOOK_ENTER] '\n',
	[QZ_RETURN] '\n',
	[QZ_ESCAPE] 27,
	[QZ_BACKSPACE] '\b',
	[QZ_LALT] Kalt,
	[QZ_LCTRL] Kctl,
	[QZ_LSHIFT] Kshift,
	[QZ_F1] KF+1,
	[QZ_F2] KF+2,
	[QZ_F3] KF+3,
	[QZ_F4] KF+4,
	[QZ_F5] KF+5,
	[QZ_F6] KF+6,
	[QZ_F7] KF+7,
	[QZ_F8] KF+8,
	[QZ_F9] KF+9,
	[QZ_F10] KF+10,
	[QZ_F11] KF+11,
	[QZ_F12] KF+12,
	[QZ_INSERT] Kins,
	[QZ_DELETE] 0x7F,
	[QZ_HOME] Khome,
	[QZ_END] Kend,
	[QZ_KP_PLUS] '+',
	[QZ_KP_MINUS] '-',
	[QZ_TAB] '\t',
	[QZ_PAGEUP] Kpgup,
	[QZ_PAGEDOWN] Kpgdown,
	[QZ_UP] Kup,
	[QZ_DOWN] Kdown,
	[QZ_LEFT] Kleft,
	[QZ_RIGHT] Kright,
	[QZ_KP_MULTIPLY] '*',
	[QZ_KP_DIVIDE] '/',
	[QZ_KP_ENTER] '\n',
	[QZ_KP_PERIOD] '.',
	[QZ_KP0] '0',
	[QZ_KP1] '1',
	[QZ_KP2] '2',
	[QZ_KP3] '3',
	[QZ_KP4] '4',
	[QZ_KP5] '5',
	[QZ_KP6] '6',
	[QZ_KP7] '7',
	[QZ_KP8] '8',
	[QZ_KP9] '9',
};

@interface apptext : NSTextView @end

@implementation apptext
- (void)doCommandBySelector:(SEL)s{}	/* Esc key beeps otherwise */
- (void)insertText:(id)arg{}	/* to avoid a latency after some time */
@end

static void
interpretdeadkey(NSEvent *e)
{
	static apptext *t;

	if(t == nil)
		t = [apptext new];
	[t interpretKeyEvents:[NSArray arrayWithObject:e]];
}

void
keystroke(int c)
{
	kbdputc(kbdq, c);
}

void
abortcompose(void)
{
	if(alting) {
		keystroke(Kalt);
		alting = 0;
	}
}

static void
getkeyboard(NSEvent *e)
{
	static NSUInteger omod;
	NSString *s;
	char c;
	NSUInteger m;
	int k;
	uint code;

	m = [e modifierFlags];

	switch([e type]){
	case NSKeyDown:
		s = [e characters];
		c = [s UTF8String][0];

		interpretdeadkey(e);

		if(m & NSCommandKeyMask){
			if(' '<=c && c<='~')
				keystroke(Kcmd+c);
			break;
		}
		k = c;
		code = [e keyCode];
		if(code<nelem(keycvt) && keycvt[code])
			k = keycvt[code];
		if(k==0)
			break;
		if(k>0)
			keystroke(k);
		else
			keystroke([s characterAtIndex:0]);
		break;

	case NSFlagsChanged:
		if(in.mbuttons || in.kbuttons){
			in.kbuttons = 0;
			if(m & NSAlternateKeyMask)
				in.kbuttons |= 2;
			if(m & NSCommandKeyMask)
				in.kbuttons |= 4;
			sendmouse();
		}else
		if(m&NSAlternateKeyMask && (omod&NSAlternateKeyMask)==0){
			keystroke(Kalt);
			alting = 1;
		}
		break;

	default:
		panic("getkey: unexpected event type");
	}
	omod = m;
}

/*
 * Devdraw does not use NSTrackingArea, that often
 * forgets to update the cursor on entering and on
 * leaving the area, and that sometimes stops sending
 * us MouseMove events, at least on OS X Lion.
 */
static void
updatecursor(void)
{
	NSCursor *c;
	int isdown, isinside;

	isinside = NSPointInRect(in.mpos, [win.content bounds]);
	isdown = (in.mbuttons || in.kbuttons);

	if(win.cursor && (isinside || isdown))
		c = win.cursor;
	else if(isinside && usebigarrow)
		c = in.bigarrow;
	else
		c = [NSCursor arrowCursor];
	[NSCursor pop];
	[c push];

	/*
	 * Without this trick, we can come back from the dock
	 * with a resize cursor.
	 */

	if (floor(NSAppKitVersionNumber) >= NSAppKitVersionNumber10_7) 
		[NSCursor unhide];
}

static void
acceptresizing(int set)
{
	NSUInteger old, style;

	old = [WIN styleMask];

	if((old | NSResizableWindowMask) != Winstyle)
		return;	/* when entering new fullscreen */

	if(set)
		style = Winstyle;
	else
		style = Winstyle & ~NSResizableWindowMask;

	if(style != old)
		[WIN setStyleMask:style];
}

static void
getmousepos(void)
{
	NSPoint p, q;

	p = [WIN mouseLocationOutsideOfEventStream];
	q = [win.content convertPoint:p fromView:nil];
	in.mpos.x = round(q.x);
	in.mpos.y = round(q.y);

	updatecursor();

	if(win.isnfs || win.isofs) {
		/* noop after removing hidebars() */
	} else if(MAC_OS_X_VERSION_MIN_REQUIRED >= 1070 && [WIN inLiveResize]==NO){
		if(p.x<12 && p.y<12 && p.x>2 && p.y>2)
			acceptresizing(0);
		else
			acceptresizing(1);
	}
}

static void
getmouse(NSEvent *e)
{
	CGFloat d;
	NSUInteger b, m;

	if([WIN isKeyWindow] == 0)
		return;

	getmousepos();

	switch([e type]){
	case NSLeftMouseDown:
	case NSLeftMouseUp:
	case NSOtherMouseDown:
	case NSOtherMouseUp:
	case NSRightMouseDown:
	case NSRightMouseUp:
		b = [NSEvent pressedMouseButtons];
		b = (b&~6) | (b&4)>>1 | (b&2)<<1;
		b = mouseswap(b);

		if(b == 1){
			m = [e modifierFlags];
			if(m & NSAlternateKeyMask){
				abortcompose();
				b = 2;
			}else
			if(m & NSCommandKeyMask)
				b = 4;
		}
		in.mbuttons = b;
		break;

	case NSScrollWheel:
		if (floor(NSAppKitVersionNumber) >= NSAppKitVersionNumber10_7)
			d = [e scrollingDeltaY];
		else
			d = [e deltaY];
		if([e hasPreciseScrollingDeltas] == NO)
			d *= 10.0;
		if(d > 20.0)
			d = 20.0;
		if(d < -20.0)
			d = -20.0;
		in.mpos.y += d;
		if(d>0)
			in.mscroll = 8;
		else
		if(d<0)
			in.mscroll = 16;
		break;

	case NSMouseMoved:
	case NSLeftMouseDragged:
	case NSRightMouseDragged:
	case NSOtherMouseDragged:
		break;

	default:
		panic("getmouse: unexpected event type");
	}
	sendmouse();
}

#define Minpinch	0.02

static void
getgesture(NSEvent *e)
{
	NSDictionary *dict;
	id obj;

	dict = dtdefaults();

	switch([e type]){
	case NSEventTypeMagnify:
		if(dict != nil && (obj = [dict objectForKey:@"MagnificationToggle"])){
			if([obj boolValue] && (fabs([e magnification]) > Minpinch))
				togglefs();
		}
		break;
	default:
		break;
	}
}

static void sendclick(NSUInteger);

static void
gettouch(NSEvent *e, int type)
{
	static int tapping;
	static uint taptime;
	NSSet *set;
	int p;

	switch(type){
	case NSTouchPhaseBegan:
		p = NSTouchPhaseTouching;
		set = [e touchesMatchingPhase:p inView:nil];
		if(set.count == 3){
			tapping = 1;
			taptime = msec();
		}else
		if(set.count > 3)
			tapping = 0;
		break;

	case NSTouchPhaseMoved:
		tapping = 0;
		break;

	case NSTouchPhaseEnded:
		p = NSTouchPhaseTouching;
		set = [e touchesMatchingPhase:p inView:nil];
		if(set.count == 0){
			if(tapping && msec()-taptime<400)
				sendclick(2);
			tapping = 0;
		}
		break;

	case NSTouchPhaseCancelled:
		break;

	default:
		panic("gettouch: unexpected event type");
	}
}

static void
sendclick(NSUInteger b)
{
	in.mbuttons = b;
	sendmouse();
	in.mbuttons = 0;
	sendmouse();
}

static void
sendmouse(void)
{
	NSUInteger b;
	Point dp, p;

	p = mousexy();
	dp = Pt(in.mpos.x - p.x, in.mpos.y - p.y);
	b = in.kbuttons | in.mbuttons | in.mscroll;
	mousetrack(dp.x, dp.y, b, msec());
	in.mscroll = 0;
	collecting = 0;
}

void
setmouse(Point p)
{
	static int first = 1;
	NSPoint q;
	NSRect r;

	if([NSApp isActive]==0 && in.willactivate==0)
		return;

	if(first){
		/* Try to move Acme's scrollbars without that! */
		CGEventSourceRef
		s = CGEventSourceCreate(kCGEventSourceStateHIDSystemState);
		CGEventSourceSetLocalEventsSuppressionInterval(s,0);
		CFRelease(s);
		first = 0;
	}
	if([WIN inLiveResize])
		return;

	in.mpos = NSMakePoint(p.x, p.y);	// race condition

	q = [win.content convertPoint:in.mpos toView:nil];
	if (floor(NSAppKitVersionNumber) < NSAppKitVersionNumber10_7) {
		#pragma clang diagnostic push
		#pragma clang diagnostic ignored "-Wdeprecated-declarations"
		q = [WIN convertBaseToScreen:q];
		#pragma clang diagnostic pop
	} else {
		q = [WIN convertRectToScreen:NSMakeRect(q.x, q.y, 0, 0)].origin;
	}
	r = [[[NSScreen screens] objectAtIndex:0] frame];
	q.y = r.size.height - q.y;	/* Quartz is top-left-based here */
	LOG(@"setmouse (%d, %d)->(%f, %f)", p.x, p.y, q.x, q.y);
	CGWarpMouseCursorPosition(NSPointToCGPoint(q));		
}

static void
followzoombutton(NSRect r)
{
	NSRect wr;
	Point p;

	wr = [WIN frame];
	wr.origin.y += wr.size.height;
	r.origin.y += r.size.height;

	getmousepos();
	p.x = (int)((r.origin.x - wr.origin.x) + in.mpos.x);
	p.y = (int)(-(r.origin.y - wr.origin.y) + in.mpos.y);
	mouseset(p);
}

static void
togglefs(void)
{
	NSWindowCollectionBehavior opt, tmp;

	if (floor(NSAppKitVersionNumber) >= NSAppKitVersionNumber10_7) {
		NSScreen *s, *s0;
		
		s = [WIN screen];
		s0 = [[NSScreen screens] objectAtIndex:0];
		
		if((s==s0 && useoldfullscreen==0) || win.isnfs) {
			[WIN toggleFullScreen:nil];
			return;
		}
	}

	[win.content retain];
	[WIN orderOut:nil];
	[WIN setContentView:nil];

	win.isofs = ! win.isofs;

	/*
	 * If we move the window from one space to another,
	 * ofs[0] and ofs[1] can be on different spaces.
	 * This "setCollectionBehavior" trick moves the
	 * window to the active space.
	 */
	opt = [WIN collectionBehavior];
	tmp = opt | NSWindowCollectionBehaviorCanJoinAllSpaces;
	[WIN setContentView:win.content];
	[WIN setCollectionBehavior:tmp];
	[WIN makeKeyAndOrderFront:nil];
	[WIN setCollectionBehavior:opt];
	[win.content release];
}

static void
makemenu(void)
{
	NSMenu *m;
	NSMenuItem *i0, *i1, *i2, *item;

	m = [NSMenu new];
	i0 = [m addItemWithTitle:@"app" action:nil keyEquivalent:@""];
	i1 = [m addItemWithTitle:@"View" action:nil keyEquivalent:@""];
	i2 = [m addItemWithTitle:@"Window" action:nil keyEquivalent:@""];
	[NSApp setMainMenu:m];
	[m release];

	m = [[NSMenu alloc] initWithTitle:@"app"];
	[m addItemWithTitle:@"Hide" action:@selector(hide:) keyEquivalent:@"h"];
	[m addItemWithTitle:@"Quit" action:@selector(terminate:) keyEquivalent:@"q"];
	[i0 setSubmenu:m];
	[m release];

	m = [[NSMenu alloc] initWithTitle:@"View"];
	item = [m addItemWithTitle:@"Enter Full Screen"
						action:@selector(calltogglefs:)
				 keyEquivalent:@"f"];
	[item setKeyEquivalentModifierMask:(NSCommandKeyMask | NSControlKeyMask)];
	[i1 setSubmenu:m];
	[m release];

	m = [[NSMenu alloc] initWithTitle:@"Window"];
	item = [m addItemWithTitle:@"Minimize"
						action:@selector(miniaturize:)
				 keyEquivalent:@"m"];
	[m addItemWithTitle:@"Zoom" action:@selector(zoom:) keyEquivalent:@""];
	[i2 setSubmenu:m];
	[m release];
}

static void
makeicon(void)
{
	NSData *d;
	NSImage *i;

	d = [NSData dataWithBytes:doc_png length:(NSUInteger)(sizeof doc_png)];
	i = [[NSImage alloc] initWithData:d];
	[NSApp setApplicationIconImage:i];
	[[NSApp dockTile] display];
	[i release];
}

QLock snarfl;

char*
getsnarf(void)
{
	NSPasteboard *pb;
	NSString *s;

	pb = [NSPasteboard generalPasteboard];

	qlock(&snarfl);
	s = [pb stringForType:NSPasteboardTypeString];
	qunlock(&snarfl);

	if(s)
		return strdup((char*)[s UTF8String]);		
	else
		return nil;
}

void
putsnarf(char *s)
{
	NSArray *t;
	NSPasteboard *pb;
	NSString *str;

	if(strlen(s) >= SnarfSize)
		return;

	t = [NSArray arrayWithObject:NSPasteboardTypeString];
	pb = [NSPasteboard generalPasteboard];
	str = [[NSString alloc] initWithUTF8String:s];

	qlock(&snarfl);
	[pb declareTypes:t owner:nil];
	[pb setString:str forType:NSPasteboardTypeString];
	qunlock(&snarfl);

	[str release];
}

void
kicklabel(char *label)
{
	if(label == nil)
		return;

	[P9AppDelegate
		performSelectorOnMainThread:@selector(callkicklabel0:)
		withObject:[NSValue valueWithPointer:label]
		waitUntilDone:YES];
}

static void
kicklabel0(char *label) {
	NSString *s;

	s = [[NSString alloc] initWithUTF8String:label];
	[win.ofs[0] setTitle:s];
	[win.ofs[1] setTitle:s];

	{
		NSArray *a = [s componentsSeparatedByString:@"."];
		if ([a count] > 1) {
			NSString *name;
			name = [a firstObject];
			if ([name integerValue] > 0) {
				name = [a lastObject];
			}
			[[NSApp dockTile] setBadgeLabel:name];				
		} else {
			[[NSApp dockTile] setBadgeLabel:s];
		}
	}
	[s release];
}

int
cursoron(int dolock)
{
	Point p;
	if(dolock)
		lock(&cursor.lk);
	p = mousexy();
	mouseset(p);
	if(dolock)
		unlock(&cursor.lk);
	return 0;
}

void
cursoroff(int d)
{
}

void
setcursor(Cursor *c)
{
	setcursor0(makecursor(c));
}

static void
setcursor0(NSCursor *c)
{
	NSCursor *d;

	d = win.cursor;
	win.cursor = c;

	updatecursor();

	if(d)
		[d release];
}

static NSCursor*
makecursor(Cursor *c)
{
	NSBitmapImageRep *r;
	NSCursor *d;
	NSImage *i;
	NSPoint p;
	int b;
	uchar *plane[5];

	r = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL
		pixelsWide:16
		pixelsHigh:16
		bitsPerSample:1
		samplesPerPixel:2
		hasAlpha:YES
		isPlanar:YES
		colorSpaceName:NSDeviceWhiteColorSpace
		bytesPerRow:2
		bitsPerPixel:1];

	[r getBitmapDataPlanes:plane];

	for(b=0; b<2*16; b++){
		plane[0][b] = c->set[b] ^ 0xFF;
		plane[1][b] = c->set[b] | c->clr[b];
	}
	p = NSMakePoint(-c->offset.x, -c->offset.y);
	i = [NSImage new];
	[i addRepresentation:r];
	[r release];

	d = [[NSCursor alloc] initWithImage:i hotSpot:p];
	[i release];
	return d;
}

void
topwin(void)
{
	[WIN performSelectorOnMainThread:@selector(makeKeyAndOrderFront:)
						  withObject:nil
					   waitUntilDone:YES];

	in.willactivate = 1;
	[NSApp activateIgnoringOtherApps:YES];
	[WIN display];
}

void
screeninit(void)
{
	/*
	 * Create window in main thread, else no cursor
	 * change while resizing.
	 */
	[P9AppDelegate performSelectorOnMainThread:@selector(callmakewin:)
							 	    withObject:nil
								 waitUntilDone:YES];

	memimageinit();
	gscreen = initimg();
	terminit();
}

// PAL - no palette handling.  Don't intend to either.
void
getcolor(ulong i, ulong *r, ulong *g, ulong *b)
{
	LOG(@"getcolor %d", i);
// PAL: Certainly wrong to return a grayscale.
	 *r = i;
	 *g = i;
	 *b = i;
}

void
setcolor(ulong index, ulong red, ulong green, ulong blue)
{
	assert(0);
}

void
cursorarrow(void)
{
	setcursor0([in.bigarrow retain]);
}

void
mousectl(Cmdbuf *cb)
{
	NSLog(@"mousectl");
}

void
mouseset(Point xy)
{
	NSPoint p, q;
	p = [WIN mouseLocationOutsideOfEventStream];
	q = [win.content convertPoint:p fromView:nil];
	LOG(@"mouseset (%f,%f)->(%d,%d)", q.x, q.y, xy.x, xy.y);

	if(q.x >= 0.0 && q.y >= 0.0) {
		if(![win.content isHidden] && !eqpt(xy, Pt(in.mpos.x, in.mpos.y)))
			setmouse(xy);		
	}
}

char*
clipread(void)
{
	return getsnarf();
}

int
clipwrite(char *snarf)
{
	putsnarf(snarf);
	return 0;
}
