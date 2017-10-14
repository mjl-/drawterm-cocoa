DESTROOT=/usr/local
ROOT=.

# The new osx-cocoa provides its own version of main.o
MAINO=main.$O

include Make.config

OFILES=\
	$(MAINO)\
	cpu.$O\
	readcons.$O\
	secstore.$O\
	latin1.$O\
	$(OS)-factotum.$O\
	$(XOFILES)\

LIBS1=\
	kern/libkern.a\
	exportfs/libexportfs.a\
	libauth/libauth.a\
	libauthsrv/libauthsrv.a\
	libbio/libbio.a\
	libsec/libsec.a\
	libmp/libmp.a\
	libmemdraw/libmemdraw.a\
	libmemlayer/libmemlayer.a\
	libdraw/libdraw.a\
	gui-$(GUI)/libgui.a\
	libc/libc.a\
	libip/libip.a\

# stupid gcc
LIBS=$(LIBS1) $(LIBS1) $(LIBS1) libmachdep.a

default: $(TARG)
$(TARG): $(OFILES) $(LIBS1) libmachdep.a
	$(CC) $(LDFLAGS) -o $(TARG) $(OFILES) $(LIBS) $(LDADD)

%.$O: %.c
	$(CC) $(CFLAGS) $*.c

clean:
	rm -f *.o */*.o */*.a *.a $(TARG)

install: $(TARG)
	install $(TARG) $(DESTROOT)/bin

kern/libkern.a: force_look
	(cd kern; $(MAKE))

exportfs/libexportfs.a: force_look
	(cd exportfs; $(MAKE))

libauth/libauth.a: force_look
	(cd libauth; $(MAKE))
	
libauthsrv/libauthsrv.a: force_look
	(cd libauthsrv; $(MAKE))

libmp/libmp.a: force_look
	(cd libmp; $(MAKE))

libsec/libsec.a: force_look
	(cd libsec; $(MAKE))

libmemdraw/libmemdraw.a: force_look
	(cd libmemdraw; $(MAKE))

libmemlayer/libmemlayer.a: force_look
	(cd libmemlayer; $(MAKE))

libdraw/libdraw.a: force_look
	(cd libdraw; $(MAKE))

libbio/libbio.a: force_look
	(cd libbio; $(MAKE))

libc/libc.a: force_look
	(cd libc; $(MAKE))

libip/libip.a: force_look
	(cd libip; $(MAKE))

gui-$(GUI)/libgui.a: force_look
	(cd gui-$(GUI); $(MAKE))

force_look:

