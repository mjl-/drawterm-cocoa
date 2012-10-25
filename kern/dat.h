
typedef struct Conf	Conf;
typedef struct Label Label;
typedef struct Mach	Mach;
typedef struct PCArch	PCArch;
typedef struct Proc	Proc;
typedef struct Segdesc	Segdesc;
typedef struct Ureg		Ureg;
typedef struct Vctl	Vctl;

#pragma incomplete Ureg

#define MAXSYSARG	5	/* for mount(fd, afd, mpt, flag, arg) */
#define STAGESIZE 2048

struct Label
{
	jmp_buf	buf;
};

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

/*
 *  things saved in the Proc structure during a notify
 */
struct Notsave
{
	ulong	svflags;
	ulong	svcs;
	ulong	svss;
};

#include "portdat.h"

struct Segdesc
{
	ulong	d0;
	ulong	d1;
};

struct Mach
{
#ifndef TLS
	Proc*	externup;
#endif
	int	new;
	int	machno;			/* physical id of processor (KNOWN TO ASSEMBLY) */
	ulong	splpc;			/* pc of last caller to splhi */

	Segdesc	*gdt;			/* gdt for this processor */

	Proc*	proc;			/* current process on this processor */

	Page*	pdbpool;
	int	pdbcnt;

	Label	sched;			/* scheduler wakeup */

	Proc*	readied;		/* for runproc */
	ulong	schedticks;		/* next forced context switch */

	int	tlbfault;
	int	tlbpurge;
	int	pfault;
	int	cs;
	int	syscall;
	int	load;
	int	intr;
	int	flushmmu;		/* make current proc flush it's mmu state */
	int	ilockdepth;
	Perf	perf;			/* performance counters */

	ulong	spuriousintr;
	int	lastintr;


	Lock	apictimerlock;
	int	cpumhz;
	uvlong	cyclefreq;		/* Frequency of user readable cycle counter */
	uvlong	cpuhz;
	int	cpuidax;
	int	cpuiddx;
	char	cpuidid[16];
	char*	cpuidtype;
	int	havetsc;
	int	havepge;
	uvlong	tscticks;
	int	pdballoc;
	int	pdbfree;


	int	spl;	// Plan 9 VX
	void	*sigstack;
	int	stack[1];
};

/*
 * KMap the structure doesn't exist, but the functions do.
 */
typedef struct KMap		KMap;
#define	VA(k)		((void*)(k))
KMap*	kmap(Page*);
void	kunmap(KMap*);

struct
{
	Lock lk;
	int	machs;			/* bitmap of active CPUs */
	int	exiting;		/* shutdown */
	int	ispanic;		/* shutdown in response to a panic */
	int	thunderbirdsarego;	/* lets the added processors continue to schedinit */
}active;

/*
 *  routines for things outside the PC model, like power management
 */
struct PCArch
{
	char*	id;
	int	(*ident)(void);		/* this should be in the model */
	void	(*reset)(void);		/* this should be in the model */
	int	(*serialpower)(int);	/* 1 == on, 0 == off */
	int	(*modempower)(int);	/* 1 == on, 0 == off */

	void	(*intrinit)(void);
	int	(*intrenable)(Vctl*);
	int	(*intrvecno)(int);
	int	(*intrdisable)(int);
	void	(*introff)(void);
	void	(*intron)(void);

	void	(*clockenable)(void);
	uvlong	(*fastclock)(uvlong*);
	void	(*timerset)(uvlong);
};

extern PCArch	*arch;			/* PC architecture */

/*
 * Each processor sees its own Mach structure at address MACHADDR.
 * However, the Mach structures must also be available via the per-processor
 * MMU information array machp, mainly for disambiguation and access to
 * the clock which is only maintained by the bootstrap processor (0).
 */
Mach* machp[MAXMACH];
	
#define	MACHP(n)	(machp[n])

#ifdef TLS
	extern __thread Mach	*m;	// Plan 9 VX
	extern __thread Proc	*up;	// Plan 9 VX
#	define thismach m
#	define setmach(x) (m = (x))
#else
	extern Mach *getmach(void);
	extern void setmach(Mach*);
#	ifdef WANT_M
#		define m getmach()
#	endif
#endif

enum
{
	SnarfSize = 64*1024,
};

#define DEVDOTDOT -1

extern Proc *_getproc(void);
extern void _setproc(Proc*);
#define	up	(_getproc())
