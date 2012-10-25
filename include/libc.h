
#define	nelem(x)	(sizeof(x)/sizeof((x)[0]))

/* the rest */
#include "lib.h"
#include "user.h"

/*
 * random number
 */
extern	void	p9srand(long);
extern	int	p9rand(void);

extern	int	p9nrand(int);
extern	long	p9lrand(void);
extern	long	p9lnrand(long);
extern	double	p9frand(void);
extern	ulong	truerand(void);			/* uses /dev/random */
extern	ulong	ntruerand(ulong);		/* uses /dev/random */

#ifndef NOPLAN9DEFINES
#define	srand	p9srand
#define	rand	p9rand
#define	nrand	p9nrand
#define	lrand	p9lrand
#define	lnrand	p9lnrand
#define	frand	p9frand
#endif


/*
 * one-of-a-kind
 */
enum
{
	PNPROC		= 1,
	PNGROUP		= 2,
};

extern	int	atexit(void(*)(void));
extern	void	exits(char*);
extern	int	postnote(int, int, char *);
extern	vlong	strtoll(char*, char**, int);


/*
 *  network services
 */
typedef struct NetConnInfo NetConnInfo;
struct NetConnInfo
{
	char	*dir;		/* connection directory */
	char	*root;		/* network root */
	char	*spec;		/* binding spec */
	char	*lsys;		/* local system */
	char	*lserv;		/* local service */
	char	*rsys;		/* remote system */
	char	*rserv;		/* remote service */
	char	*laddr;		/* local address */
	char	*raddr;		/* remote address */
};
extern	NetConnInfo*	getnetconninfo(char*, int);
extern	void		freenetconninfo(NetConnInfo*);

/*
 * system calls
 *
 */
#define	STATMAX	65535U	/* max length of machine-independent stat structure */
#define	DIRMAX	(sizeof(Dir)+STATMAX)	/* max length of Dir structure */
#define	ERRMAX	128	/* max length of error string */


/* rfork */
enum
{
	RFNAMEG		= (1<<0),
	RFENVG		= (1<<1),
	RFFDG		= (1<<2),
	RFNOTEG		= (1<<3),
	RFPROC		= (1<<4),
	RFMEM		= (1<<5),
	RFNOWAIT	= (1<<6),
	RFCNAMEG	= (1<<10),
	RFCENVG		= (1<<11),
	RFCFDG		= (1<<12),
	RFREND		= (1<<13),
	RFNOMNT		= (1<<14)
};


extern	Dir*	dirstat(char*);
extern	Dir*	dirfstat(int);
extern	int	dirwstat(char*, Dir*);
extern	int	dirfwstat(int, Dir*);
extern	long	dirread(int, Dir**);
extern	void	nulldir(Dir*);
extern	long	dirreadall(int, Dir**);
extern	int	getpid(void);
extern	int	getppid(void);
extern	void	rerrstr(char*, uint);
extern	char*	sysname(void);
extern	void	werrstr(char*, ...);
