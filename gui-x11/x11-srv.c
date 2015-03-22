#include <u.h>
#include <error.h>
#include "x11-inc.h"

#include <libc.h>
#include <draw.h>
#include <memdraw.h>
#include <keyboard.h>
#include <cursor.h>

#define Image IMAGE
#include <kern/mem.h>
#include <kern/dat.h>
#include <user.h>

#include <kern/screen.h>
#include <bigarrow.h>

#include "x11-memdraw.h"
#include "devdraw.h"

#define argv0 "drawterm"

#define Mask MouseMask|ExposureMask|StructureNotifyMask|KeyPressMask|KeyReleaseMask|EnterWindowMask|LeaveWindowMask|FocusChangeMask

extern int		kbdputc(Queue*, int);
void runxevent(XEvent*);

/* perfect approximation to NTSC = .299r+.587g+.114b when 0 ≤ r,g,b < 256 */
#define RGB2K(r,g,b)	((156763*(r)+307758*(g)+59769*(b))>>19)

static int xdraw(Memdrawparam*);
static void xproc(void *arg);

int fullscreen;

Memimage *gscreen;				/* needed by devmouse */


void
memimageinit(void)
{
	static int didinit = 0;
	
	if(didinit)
		return;

	didinit = 1;
	_memimageinit();
	
	xfillcolor(memblack, memblack->r, 0);
	xfillcolor(memwhite, memwhite->r, 1);
}

void
screeninit(void)
{
	_memmkcmap();
	memimageinit();
	gscreen = _xattach("drawterm", NULL);
	terminit();
	drawqlock();
	_flushmemscreen(gscreen->r);
	drawqunlock();
	kproc("xscreen", xproc, nil);
}

uchar*
attachscreen(Rectangle *r, ulong *chan, int *depth,
	int *width, int *softscreen, void **X)
{
	*r = gscreen->r;
	*chan = gscreen->chan;
	*depth = gscreen->depth;
	*width = gscreen->width;
	if(X != nil)
		*X = gscreen->X;
	*softscreen = 1;

	return gscreen->data->bdata;
}

void
mouseset(Point xy)
{
	drawqlock();
	XWarpPointer(_x.display, None, _x.drawable, 0, 0, 0, 0, xy.x, xy.y);
	XFlush(_x.display);
	drawqunlock();
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
setcursor(Cursor *curs)
{
	_xsetcursor(curs);
}

static void
xproc(void *arg)
{
	XEvent event;

	XSelectInput(_x.display, _x.drawable, Mask);
	for(;;) {
		while(XPending(_x.display)){
			XNextEvent(_x.display, &event);
			runxevent(&event);
		}
	}
}

static void
xmapping(XEvent *e)
{
	XMappingEvent *xe;

	if(e->type != MappingNotify)
		return;
	xe = (XMappingEvent*)e;
	USED(xe);
}

static void
xresize(XEvent *e)
{
	XResizeRequestEvent *xe;
	XDrawable pixmap;
	Memimage *m;
	Rectangle r;

	if(e->type != ResizeRequest)
		return;
	xe = (XResizeRequestEvent*)e;
	r = Rect(0, 0, xe->width, xe->height);
/*
	XFlush(_x.display);
	XCopyArea(_x.display, _x.screenpm, _x.drawable, xgccopy, r.min.x, r.min.y,
		Dx(r), Dy(r), r.min.x, r.min.y);
	XSync(_x.display, False);
*/
	drawqlock();
	XFreePixmap(_x.display, _x.screenpm);
	pixmap = XCreatePixmap(_x.display, _x.drawable, Dx(r), Dy(r), _x.depth);
	m = _xallocmemimage(r, _x.chan, pixmap);
	_x.screenpm = pixmap;
	gscreen = m;
	drawqunlock();

	termreplacescreenimage(gscreen);
	drawreplacescreenimage(gscreen);
}

void
getcolor(ulong i, ulong *r, ulong *g, ulong *b)
{
	ulong v;
	
	v = cmap2rgb(i);
	*r = (v>>16)&0xFF;
	*g = (v>>8)&0xFF;
	*b = v&0xFF;
}

void
setcolor(ulong i, ulong r, ulong g, ulong b)
{
	/* no-op */
}

int
atlocalconsole(void)
{
	char *p, *q;
	char buf[128];

	p = getenv("DRAWTERM_ATLOCALCONSOLE");
	if(p && atoi(p) == 1)
		return 1;

	p = getenv("DISPLAY");
	if(p == nil)
		return 0;

	/* extract host part */
	q = strchr(p, ':');
	if(q == nil)
		return 0;
	*q = 0;

	if(strcmp(p, "") == 0)
		return 1;

	/* try to match against system name (i.e. for ssh) */
	if(gethostname(buf, sizeof buf) == 0){
		if(strcmp(p, buf) == 0)
			return 1;
		if(strncmp(p, buf, strlen(p)) == 0 && buf[strlen(p)]=='.')
			return 1;
	}

	return 0;
}

/*
 * Cut and paste.  Just couldn't stand to make this simple...
 */

typedef struct Clip Clip;
struct Clip
{
	char buf[SnarfSize];
	QLock lk;
};
Clip clip;

#undef long	/* sic */
#undef ulong

char*
clipread(void)
{
	return _xgetsnarf();
}

int
clipwrite(char *buf)
{
	_xputsnarf(buf);
	return 0;
}

void
mousectl(Cmdbuf *cb)
{
}

char*
getconf(char *name)
{
	return getenv(name);	/* leak */
}

/*
 * Match queued mouse reads with queued mouse events.
 */
void
matchmouse(void)
{
	Wsysmsg m;
	
	while(mouse.ri != mouse.wi && mousetags.ri != mousetags.wi){
		m.type = Rrdmouse;
		m.tag = mousetags.t[mousetags.ri++];
		if(mousetags.ri == nelem(mousetags.t))
			mousetags.ri = 0;
		m.mouse = mouse.m[mouse.ri];
		m.resized = mouse.resized;
		/*
		if(m.resized)
			fprint(2, "sending resize\n");
		*/
		mouse.resized = 0;
		mouse.ri++;
		if(mouse.ri == nelem(mouse.m))
			mouse.ri = 0;
		replymsg(&m);
	}
}
static int kbuttons;
static int altdown;
static int kstate;

static void
sendmouse(Mouse m)
{
	m.buttons |= kbuttons;
	mouse.m[mouse.wi] = m;
	mouse.wi++;
	if(mouse.wi == nelem(mouse.m))
		mouse.wi = 0;
	if(mouse.wi == mouse.ri){
		mouse.stall = 1;
		mouse.ri = 0;
		mouse.wi = 1;
		mouse.m[0] = m;
		/* fprint(2, "mouse stall\n"); */
	}
	matchmouse();
}

/*
 * Handle an incoming X event.
 */
void
runxevent(XEvent *xev)
{
	int c;
	KeySym k;
	static Mouse m;
	XButtonEvent *be;
	XKeyEvent *ke;

#ifdef SHOWEVENT
	static int first = 1;
	if(first){
		dup(create("/tmp/devdraw.out", OWRITE, 0666), 1);
		setbuf(stdout, 0);
		first = 0;
	}
#endif

	if(xev == 0)
		return;

#ifdef SHOWEVENT
	print("\n");
	ShowEvent(xev);
#endif

	switch(xev->type){
	case Expose:
		_xexpose(xev);
		break;
	
	case DestroyNotify:
		if(_xdestroy(xev))
			exits(0);
		break;

	case ConfigureNotify:
		if(_xconfigure(xev)){
			mouse.resized = 1;
			_xreplacescreenimage();
			sendmouse(m);
		}
		break;

	case ButtonPress:
		be = (XButtonEvent*)xev;
		if(be->button == 1) {
			if(kstate & ControlMask)
				be->button = 2;
			else if(kstate & Mod1Mask)
				be->button = 3;
		}
		// fall through
	case ButtonRelease:
		altdown = 0;
		// fall through
	case MotionNotify:
		if(mouse.stall)
			return;
		if(_xtoplan9mouse(xev, &m) < 0)
			return;
		sendmouse(m);
		break;
	
	case KeyRelease:
	case KeyPress:
		ke = (XKeyEvent*)xev;
		XLookupString(ke, NULL, 0, &k, NULL);
		c = ke->state;
		switch(k) {
		case XK_Alt_L:
		case XK_Meta_L:	/* Shift Alt on PCs */
		case XK_Alt_R:
		case XK_Meta_R:	/* Shift Alt on PCs */
		case XK_Multi_key:
			if(xev->type == KeyPress)
				altdown = 1;
			else if(altdown) {
				altdown = 0;
				sendalt();
			}
			break;
		}

		switch(k) {
		case XK_Control_L:
			if(xev->type == KeyPress)
				c |= ControlMask;
			else
				c &= ~ControlMask;
			goto kbutton;
		case XK_Alt_L:
		case XK_Shift_L:
			if(xev->type == KeyPress)
				c |= Mod1Mask;
			else
				c &= ~Mod1Mask;
		kbutton:
			kstate = c;
			if(m.buttons || kbuttons) {
				altdown = 0; // used alt
				kbuttons = 0;
				if(c & ControlMask)
					kbuttons |= 2;
				if(c & Mod1Mask)
					kbuttons |= 4;
				sendmouse(m);
				break;
			}
		}

		if(xev->type != KeyPress)
			break;
		if(k == XK_F11){
			fullscreen = !fullscreen;
			_xmovewindow(fullscreen ? screenrect : windowrect);
			return;
		}
		if(kbd.stall)
			return;
		if((c = _xtoplan9kbd(xev)) < 0)
			return;
		kbd.r[kbd.wi++] = c;
		if(kbd.wi == nelem(kbd.r))
			kbd.wi = 0;
		if(kbd.ri == kbd.wi)
			kbd.stall = 1;
		matchkbd();
		break;
	
	case FocusOut:
		/*
		 * Some key combinations (e.g. Alt-Tab) can cause us
		 * to see the key down event without the key up event,
		 * so clear out the keyboard state when we lose the focus.
		 */
		kstate = 0;
		abortcompose();
		break;
	
	case SelectionRequest:
		_xselect(xev);
		break;
	}
}

