#import <Cocoa/Cocoa.h>

@interface appdelegate : NSObject <NSApplicationDelegate>
{
	NSCursor *_arrowCursor;
}

@property (assign) NSCursor *arrowCursor;

@end
