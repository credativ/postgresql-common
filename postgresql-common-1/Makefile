# Makefile for postgresql-common Debian package

PREFIX ?= /usr
BINDIR = $(PREFIX)/bin
SBINDIR = $(PREFIX)/sbin
MANDIR = $(PREFIX)/man

LINKS = clusterdb createdb createlang createuser dropdb droplang dropuser pg_dump pg_dumpall pg_restore psql vacuumdb vacuumlo

clean:

install:	pg_wrapper
	[ -z "$(DESTDIR)" ] || mkdir -p "$(DESTDIR)"
	install -D -m 755 pg_wrapper $(DESTDIR)/$(BINDIR)/pg_wrapper
	install -D -m 755 pg_lsclusters $(DESTDIR)/$(BINDIR)/pg_lsclusters
	install -D -m 755 pg_createcluster $(DESTDIR)/$(SBINDIR)/pg_createcluster
	install -D -m 755 pg_startcluster $(DESTDIR)/$(SBINDIR)/pg_startcluster
	install -D -m 755 pg_stopcluster $(DESTDIR)/$(SBINDIR)/pg_stopcluster
	install -D -m 755 pg_reloadcluster $(DESTDIR)/$(SBINDIR)/pg_reloadcluster
	
	cd $(DESTDIR)/$(BINDIR) && \
	    for f in $(LINKS); do \
	        ln -sf pg_wrapper $$f; \
	    done
