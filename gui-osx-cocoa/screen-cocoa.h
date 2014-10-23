#import <Cocoa/Cocoa.h>

@interface P9AppDelegate : NSObject <NSApplicationDelegate, NSWindowDelegate>
{
	NSCursor *_arrowCursor;
}

@property (assign) NSCursor *arrowCursor;

@end
