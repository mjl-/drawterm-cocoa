ROOT=..
include ../Make.config
LIB=libgui.a

OFILES=\
	alloc.$O\
	cload.$O\
	draw.$O\
	load.$O\
	mouseswap.$O\
	cocoa-screen.$O\
	main-cocoa.$O

default: $(LIB)
$(LIB): $(OFILES)
	$(AR) r $(LIB) $(OFILES)
	$(RANLIB) $(LIB)

%.$O: %.c
	$(CC) $(CFLAGS) $*.c

%.$O: %.m
	$(CC) $(CFLAGS) $*.m
