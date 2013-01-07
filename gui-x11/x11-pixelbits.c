#include "u.h"
#include "libc.h"

#include <draw.h>
#include <memdraw.h>

/*
 * Do NOT call this directly.  pixelbits is a wrapper
 * around this that fetches the bits from the X server
 * when necessary.
 */
u32int
_pixelbits(Memimage *i, Point pt)
{
	uchar *p;
	u32int val;
	int off, bpp, npack;

	val = 0;
	p = byteaddr(i, pt);
	switch(bpp=i->depth){
	case 1:
	case 2:
	case 4:
		npack = 8/bpp;
		off = pt.x%npack;
		val = p[0] >> bpp*(npack-1-off);
		val &= (1<<bpp)-1;
		break;
	case 8:
		val = p[0];
		break;
	case 16:
		val = p[0]|(p[1]<<8);
		break;
	case 24:
		val = p[0]|(p[1]<<8)|(p[2]<<16);
		break;
	case 32:
		val = p[0]|(p[1]<<8)|(p[2]<<16)|(p[3]<<24);
		break;
	}
	while(bpp<32){
		val |= val<<bpp;
		bpp *= 2;
	}
	return val;
}
