#import <Foundation/NSObjCRuntime.h>

#include "u.h"
#include "lib.h"

enum
{
	Nbutton = 10
};

static int debug = 0;

static struct
{
	int b[Nbutton];
	int init;
} map;

static void
initmap(void)
{
	char *p;
	int i;

	p = getenv("mousedebug");
	if(p && p[0])
		debug = atoi(p);

	for(i=0; i<Nbutton; i++)
		map.b[i] = i;
	map.init = 1;
	p = getenv("mousebuttonmap");
	if(p)
		for(i=0; i<Nbutton && p[i]; i++)
			if('0' <= p[i] && p[i] <= '9')
				map.b[i] = p[i] - '1';
	if(debug){
		fprint(2, "mousemap: ");
		for(i=0; i<Nbutton; i++)
			fprint(2, " %d", 1+map.b[i]);
		fprint(2, "\n");
	}
}

NSUInteger
mouseswap(NSUInteger but)
{
	int i;
	NSUInteger nbut;

	if(!map.init)
		initmap();
	
	nbut = 0;
	for(i=0; i<Nbutton; i++)
		if((but&(1<<i)) && map.b[i] >= 0)
			nbut |= 1<<map.b[i];
	if(debug)
		fprint(2, "swap %#b -> %#b\n", but, nbut);
	return nbut;
}
