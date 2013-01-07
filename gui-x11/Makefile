ROOT=..
include ../Make.config
LIB=libgui.a

OFILES=\
	x11.$O\
	x11-pixelbits.$O\
	keysym2ucs-x11.$O

default: $(LIB)
$(LIB): $(OFILES)
	$(AR) r $(LIB) $(OFILES)
	$(RANLIB) $(LIB)

