ROOT=..
include ../Make.config
LIB=libdraw.a

OFILES=\
	alloc.$O\
	allocimagemix.$O\
	arith.$O\
	bezier.$O\
	border.$O\
	buildfont.$O\
	bytesperline.$O\
	chan.$O\
	cloadimage.$O\
	computil.$O\
	creadimage.$O\
	debug.$O\
	defont.$O\
	draw.$O\
	drawrepl.$O\
	egetrect.$O\
	ellipse.$O\
	emenuhit.$O\
	fmt.$O\
	font.$O\
	freesubfont.$O\
	getdefont.$O\
	getrect.$O\
	getsubfont.$O\
	icossin.$O\
	icossin2.$O\
	init.$O\
	keyboard.$O\
	line.$O\
	menuhit.$O\
	mkfont.$O\
	mouse.$O\
	openfont.$O\
	poly.$O\
	loadimage.$O\
	readimage.$O\
	readsubfont.$O\
	rectclip.$O\
	replclipr.$O\
	rgb.$O\
	scroll.$O\
	string.$O\
	stringbg.$O\
	stringsubfont.$O\
	stringwidth.$O\
	subfont.$O\
	subfontcache.$O\
	subfontname.$O\
	unloadimage.$O\
	window.$O\
	writecolmap.$O\
	writeimage.$O\
	writesubfont.$O\

#	event.$O\
#	newwindow.$O\
#	readcolmap.$O\


default: $(LIB)
$(LIB): $(OFILES)
	$(AR) r $(LIB) $(OFILES)
	$(RANLIB) $(LIB)

%.$O: %.c
	$(CC) $(CFLAGS) $*.c

