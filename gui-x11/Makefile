ROOT=..
include ../Make.config
LIB=libgui.a

OFILES=\
	x11-alloc.$O\
	x11-cload.$O\
	x11-draw.$O\
	x11-fill.$O\
	x11-get.$O\
	x11-init.$O\
	x11-itrans.$O\
	x11-keysym2ucs.$O\
	x11-load.$O\
	x11-pixelbits.$O\
	x11-srv.$O\
	x11-unload.$O\
	x11-wsys.$O\

default: $(LIB)
$(LIB): $(OFILES)
	$(AR) r $(LIB) $(OFILES)
	$(RANLIB) $(LIB)

