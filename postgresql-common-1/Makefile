# Makefile for postgresql-common Debian package

PREFIX ?= /usr
BINDIR = $(PREFIX)/bin
MANDIR = $(PREFIX)/man

CFLAGS = -g -Wall

PROGS = pg_wrapper

LINKS = pg_exec pg_default psql pg_dump pg_dumpall initdb createdb createuser dropdb dropuser pg_restore clusterdb vacuumdb psql

SRCS  = pg_wrapper.c pg_default.c pg_files.c pg_exec.c

OBJS  = pg_wrapper.o pg_default.o pg_files.o pg_exec.o

all:	pg_wrapper

clean:
	-rm $(PROGS) $(LINKS) $(OBJS)
	-rm *~

install:	pg_wrapper
	[ -z "$(DESTDIR)" ] || mkdir -p "$(DESTDIR)"
	install -D -m 755 pg_wrapper $(DESTDIR)/$(BINDIR)/pg_wrapper
	install -D -m 755 pg_lsclusters $(DESTDIR)/$(BINDIR)/pg_lsclusters
	
	cd $(DESTDIR)/$(BINDIR) && \
	    for f in $(LINKS); do \
	        ln -sf pg_wrapper $$f; \
	    done

pg_wrapper:	$(OBJS)
	gcc $(CFLAGS) $(OBJS) -o $@ 

$(OBJS):	pg_wrapper.h
