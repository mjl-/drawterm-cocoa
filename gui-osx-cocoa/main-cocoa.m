#import <Cocoa/Cocoa.h>
#import "screen-cocoa.h"

#undef nil
#include "u.h"
#include "lib.h"
#include "kern/dat.h"
#include "kern/fns.h"

extern int dtmain(int argc, char **argv);

static int threadargc;
static char **threadargv;

int main(int argc, char *argv[])
{
	Proc *p;

	threadargc = argc;
	threadargv = argv;

	osinit();
	p = newproc();
	p->fgrp = dupfgrp(nil);
	p->rgrp = newrgrp();
	p->pgrp = newpgrp();
	_setproc(p);

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
	[[NSThread currentThread] setName:@"com.bell-labs.plan9.cpumain"];
	dtmain(threadargc, threadargv);
}