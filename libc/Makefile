ROOT=..
include ../Make.config
LIB=libc.a

NUM=\
	charstod.$O\
	pow10.$O\

FMTOFILES=\
	dofmt.$O\
	dorfmt.$O\
	errfmt.$O\
	fltfmt.$O\
	fmt.$O\
	fmtfd.$O\
	fmtlock.$O\
	fmtprint.$O\
	fmtquote.$O\
	fmtrune.$O\
	fmtstr.$O\
	fmtvprint.$O\
	fprint.$O\
	nan64.$O\
	print.$O\
	runefmtstr.$O\
	runeseprint.$O\
	runesmprint.$O\
	runesnprint.$O\
	runesprint.$O\
	runevseprint.$O\
	runevsmprint.$O\
	runevsnprint.$O\
	seprint.$O\
	smprint.$O\
	snprint.$O\
	sprint.$O\
	vfprint.$O\
	vseprint.$O\
	vsmprint.$O\
	vsnprint.$O\
	$(NUM)\

UTFOFILES=\
	rune.$O\
	runestrcpy.$O\
	runestrdup.$O\
	runestrlen.$O\
	runestrecpy.$O\
	runestrncat.$O\
	runestrncmp.$O\
	runestrncpy.$O\
	runestrrchr.$O\
	runestrstr.$O\
	runetype.$O\
	utfecpy.$O\
	utflen.$O\
	utfnlen.$O\
	utfrrune.$O\
	utfrune.$O\
	utfutf.$O\

9SYSOFILES=\
	announce.$O\
	convD2M.$O\
	convM2D.$O\
	convM2S.$O\
	convS2M.$O\
	dial.$O\
	dirfstat.$O\
	dirfwstat.$O\
	dirmodefmt.$O\
	dirread.$O\
	dirstat.$O\
	dirwstat.$O\
	fcallfmt.$O\
	getpid.$O\
	iounit.$O\
	nsec.$O\
	pushssl.$O\
	pushtls.$O\
	read9pmsg.$O\
	sysfatal.$O\
	time.$O\
	truerand.$O\


PORTOFILES=\
	cleanname.$O\
	crypt.$O\
	encodefmt.$O\
	frand.$O\
	getfields.$O\
	lnrand.$O\
	lock.$O\
	netmkaddr.$O\
	rand.$O\
	readn.$O\
	rune.$O\
	runestrcat.$O\
	runestrchr.$O\
	runestrcmp.$O\
	runestrcpy.$O\
	runestrdup.$O\
	runestrecpy.$O\
	runestrlen.$O\
	runestrncat.$O\
	runestrncmp.$O\
	runestrncpy.$O\
	runestrrchr.$O\
	runestrstr.$O\
	runetype.$O\
	strecpy.$O\
	strtod.$O\
	strtoll.$O\
	tokenize.$O\
	u16.$O\
	u32.$O\
	u64.$O\


OFILES=\
	$(9SYSOFILES)\
	$(PORTOFILES)\
	$(FMTOFILES)\
	$(UTFOFILES)\
	mallocz.$O\

default: $(LIB)
$(LIB): $(OFILES)
	$(AR) r $(LIB) $(OFILES)
	$(RANLIB) $(LIB)

%.$O: %.c
	$(CC) $(CFLAGS) $*.c

%.$O: fmt/%.c
	$(CC) $(CFLAGS) -Ifmt fmt/$*.c

%.$O: utf/%.c
	$(CC) $(CFLAGS) -Iutf utf/$*.c

%.$O: 9sys/%.c
	$(CC) $(CFLAGS) 9sys/$*.c

%.$O: port/%.c
	$(CC) $(CFLAGS) -Ifmt port/$*.c

