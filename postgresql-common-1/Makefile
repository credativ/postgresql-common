# Makefile for postgresql-common Debian package

BINDIR = $(prefix)/bin
MANDIR = $(prefix)/man

CFLAGS = -g -Wall

PROGS = pg_wrapper

LINKS = pg_exec pg_default psql

SRCS  = pg_wrapper.c pg_default.c pg_files.c pg_exec.c

OBJS  = pg_wrapper.o pg_default.o pg_files.o pg_exec.o

all:	pg_wrapper

clean:
	-rm $(PROGS) $(LINKS) $(OBJS)
	-rm *~

install:	pg_wrapper
	install pg_wrapper $(BINDIR)

$(LINKS):	install
	cd $(BINDIR) && \
		for f in $(LINKS); do \
			ln -f pg_wrapper $f \
		done

pg_wrapper:	$(OBJS)
	gcc $(CFLAGS) $(OBJS) -o $@ 

$(OBJS):	pg_wrapper.h
