typedef struct Cursorinfo Cursorinfo;
typedef struct Mouseinfo	Mouseinfo;
typedef struct Mousestate	Mousestate;
typedef struct Screeninfo Screeninfo;

struct Cursorinfo {
	Cursor	cursor;
	Lock 	lk;
};

struct Mousestate
{
	Point	xy;		/* mouse.xy */
	int	buttons;	/* mouse.buttons */
	ulong	counter;	/* increments every update */
	ulong	msec;		/* time of last event */
};

struct Mouseinfo
{
	Lock lk;
	Mousestate state;
	int	dx;
	int	dy;
	int	track;		/* dx & dy updated */
	int	redraw;		/* update cursor on screen */
	ulong	lastcounter;	/* value when /dev/mouse read */
	ulong	lastresize;
	ulong	resize;
	Rendez	r;
	Ref  ref;
	QLock 	qlk;
	int	open;
	int	inopen;
	int	acceleration;
	int	maxacc;
	Mousestate	queue[16];	/* circular buffer of click events */
	int	ri;		/* read index into queue */
	int	wi;		/* write index into queue */
	uchar	qfull;		/* queue is full */
};

/* devmouse.c */
extern void mousectl(Cmdbuf*);
extern void mousetrack(int, int, int, int);
extern Point mousexy(void);

struct Screeninfo {
	Lock		lk;
	Memimage	*newsoft;
	int		reshaped;
	int		depth;
	int		dibtype;
};

extern	Memimage *gscreen;
extern	Cursorinfo cursor;
extern	Screeninfo screeninfo;
extern	Cursor arrow;

/* screen.c */
extern uchar* attachscreen(Rectangle*, ulong*, int*, int*, int*);
void	screeninit(void);
void	screenload(Rectangle, int, uchar *, Point, int);
void	getcolor(ulong, ulong*, ulong*, ulong*);
void	refreshrect(Rectangle);
void	cursorarrow(void);
extern void	setcursor(Cursor*);
void	mouseset(Point);
void	flushmemscreen(Rectangle);
extern int	cursoron(int);
extern void	cursoroff(int);
#define blankscreen(x)

/* devdraw.c */
extern void	deletescreenimage(void);
extern void	resetscreenimage(void);
extern int		drawhasclients(void);
extern ulong	blanktime;
extern void	setscreenimageclipr(Rectangle);
extern void	drawflush(void);
extern void	drawflushr(Rectangle);
extern int drawidletime(void);
extern QLock	drawlock;
void	drawqlock(void);
void	drawqunlock(void);
int	drawcanqlock(void);

extern void drawreplacescreenimage(Memimage*);
//extern void drawreplacescreenimage(void);

#define ishwimage(x) (0)

/* term.c */
void	terminit(void);
void	termredraw(void);
void	termreplacescreenimage(Memimage*);
