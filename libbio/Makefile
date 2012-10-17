ROOT=..
include ../Make.config
LIB=libbio.a

OFILES=\
	bbuffered.$O\
	bfildes.$O\
	bflush.$O\
	bgetrune.$O\
	bgetc.$O\
	bgetd.$O\
	binit.$O\
	boffset.$O\
	bprint.$O\
	bputrune.$O\
	bputc.$O\
	brdline.$O\
	brdstr.$O\
	bread.$O\
	bseek.$O\
	bwrite.$O\
	bvprint.$O\

HFILES=/sys/include/bio.h

default: $(LIB)
$(LIB): $(OFILES)
	$(AR) r $(LIB) $(OFILES)
	$(RANLIB) $(LIB)

%.$O: %.c
	$(CC) $(CFLAGS) $*.c
