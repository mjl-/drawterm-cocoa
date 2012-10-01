#import <Cocoa/Cocoa.h>
#import "screen-cocoa.h"

extern int dtmain(int argc, char **argv);

static int threadargc;
static char **threadargv;

int main(int argc, char *argv[])
{
	threadargc = argc;
	threadargv = argv;

	[NSApplication sharedApplication];
	[NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];
	[NSApp setDelegate:[appdelegate new]];
	[NSApp activateIgnoringOtherApps:YES];
	[NSApp run];

	return 0;
}

void
calldtmain(void)
{
	[[NSThread currentThread] setName:@"dtmain"];
	dtmain(threadargc, threadargv);
}