POD2MAN=pod2man --center "Debian PostgreSQL infrastructure" -r "Debian"
POD1PROGS = pg_conftool.1 \
	    pg_createcluster.1 \
	    pg_ctlcluster.1 \
	    pg_dropcluster.1 \
	    pg_lsclusters.1 \
	    pg_renamecluster.1 \
	    pg_upgradecluster.1 \
	    pg_wrapper.1
POD1PROGS_POD = pg_buildext.1 \
		pg_virtualenv.1 \
		dh_make_pgxs/dh_make_pgxs.1
POD8PROGS = pg_updatedicts.8

all: man

man: $(POD1PROGS) $(POD1PROGS_POD) $(POD8PROGS)

%.1: %.pod
	$(POD2MAN) --quotes=none --section 1 $< $@

%.1: %
	$(POD2MAN) --quotes=none --section 1 $< $@

%.8: %
	$(POD2MAN) --quotes=none --section 8 $< $@

clean:
	rm -f *.1 *.8 dh_make_pgxs/*.1

# rpm

DPKG_VERSION=$(shell sed -ne '1s/.*(//; 1s/).*//p' debian/changelog)
RPMDIR=$(CURDIR)/rpm
TARBALL=$(RPMDIR)/SOURCES/postgresql-common_$(DPKG_VERSION).tar.xz

rpmbuild: $(TARBALL)
	rpmbuild -D"%_topdir $(RPMDIR)" --define='version $(DPKG_VERSION)' -ba rpm/postgresql-common.spec

$(TARBALL):
	mkdir -p $(dir $(TARBALL))
	git archive --prefix=postgresql-common-$(DPKG_VERSION)/ HEAD | xz > $(TARBALL)

rpminstall:
	sudo rpm --upgrade --replacefiles --replacepkgs -v $(RPMDIR)/RPMS/noarch/*-$(DPKG_VERSION)-*.rpm

rpmremove:
	-sudo rpm -e postgresql-common postgresql-client-common postgresql-server-dev-all

rpmclean:
	rm -rf $(TARBALL) $(RPMDIR)/BUILD
