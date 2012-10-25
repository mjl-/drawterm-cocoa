
#define	nelem(x)	(sizeof(x)/sizeof((x)[0]))

/* the rest */
#include "lib.h"
#include "user.h"

extern	int	atexit(void(*)(void));
extern	void	exits(char*);
extern	int	postnote(int, int, char *);
