ROOT=..
include ../Make.config
LIB=libmemdraw.a

OFILES=\
	addr.$O\
	alloc.$O\
	arc.$O\
	cload.$O\
	cmap.$O\
	cread.$O\
	defont.$O\
	draw.$O\
	ellipse.$O\
	fillpoly.$O\
	hwdraw.$O\
	iprint.$O\
	line.$O\
	load.$O\
	memsetchan.$O\
	openmemsubfont.$O\
	poly.$O\
	read.$O\
	string.$O\
	subfont.$O\
	unload.$O\
	write.$O

default: $(LIB)
$(LIB): $(OFILES)
	$(AR) r $(LIB) $(OFILES)
	$(RANLIB) $(LIB)

%.$O: %.c
	$(CC) $(CFLAGS) $*.c

