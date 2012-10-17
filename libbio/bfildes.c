#include	<u.h>
#include	<libc.h>
#undef long
#include	<bio.h>

int
Bfildes(Biobuf *bp)
{

	return bp->fid;
}
