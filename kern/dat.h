
typedef struct Conf	Conf;
typedef struct Label Label;
typedef struct Ureg		Ureg;

#pragma incomplete Ureg

#define MAXSYSARG	5	/* for mount(fd, afd, mpt, flag, arg) */


struct Conf
{
	ulong	nmach;		/* processors */
	ulong	nproc;		/* processes */
	ulong	monitor;	/* has monitor? */
	ulong	npage0;		/* total physical pages of memory */
	ulong	npage1;		/* total physical pages of memory */
	ulong	npage;		/* total physical pages of memory */
	ulong	upages;		/* user page pool */
	ulong	nimage;		/* number of page cache image headers */
	ulong	nswap;		/* number of swap pages */
	int	nswppo;		/* max # of pageouts per segment pass */
	ulong	base0;		/* base of bank 0 */
	ulong	base1;		/* base of bank 1 */
	ulong	copymode;	/* 0 is copy on write, 1 is copy on reference */
	ulong	ialloc;		/* max interrupt time allocation in bytes */
	ulong	pipeqsize;	/* size in bytes of pipe queues */
	int	nuart;		/* number of uart devices */
};

struct Label
{
	jmp_buf	buf;
};

#include "portdat.h"

enum
{
	SnarfSize = 64*1024,
};

#define DEVDOTDOT -1

extern Proc *_getproc(void);
extern void _setproc(Proc*);
#define	up	(_getproc())
