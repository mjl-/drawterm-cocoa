#include "u.h"
#include "lib.h"
#include 	"mem.h"
#include "dat.h"
#include "fns.h"
#include "error.h"

Proc *up;
Conf conf = 
{
	1, 					/* processors */
	100,				/* processes */
	1,					/* has monitor? */
	1024*1024*1024, 	/* total physical pages of memory */
	1024*1024*1024,		/* total physical pages of memory */
	1024*1024*1024,		/* total physical pages of memory */
	1024*1024*1024,		/* user page pool */
	1024*1024*1024,		/* number of page cache image headers */
	1024*1024*1024,		/* number of swap pages */
	1024*1024*1024, 	/* max # of pageouts per segment pass */
	1024*1024*1024,		/* base of bank 0 */
	1024*1024*1024,		/* base of bank 1 */
	1024*1024*1024,		/* 0 is copy on write, 1 is copy on reference */
	1024*1024*1024,		/* max interrupt time allocation in bytes */
	1024*1024*1024,		/* size in bytes of pipe queues */
	0,					/* number of uart devices */
};

char *eve = "eve";
ulong kerndate;
int cpuserver;
char hostdomain[] = "drawterm.net";
