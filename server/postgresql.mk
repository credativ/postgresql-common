#!/usr/bin/make -f

# The PostgreSQL server packages include this in their debian/rules file.

ifndef MAJOR_VER
$(error MAJOR_VER must be defined before including this file)
endif

# path to auxiliary build files
AUX_MK_DIR = /usr/share/postgresql-common/server

# version comparison
version_ge = $(shell dpkg --compare-versions $(MAJOR_VER) ge $(1) && echo y)

# include dpkg makefiles
include /usr/share/dpkg/architecture.mk
include /usr/share/dpkg/pkg-info.mk
include /usr/share/dpkg/vendor.mk
export DEB_BUILD_MAINT_OPTIONS = hardening=+all
DPKG_EXPORT_BUILDFLAGS = 1
include /usr/share/dpkg/buildflags.mk

# strict symbol checking
export DPKG_GENSYMBOLS_CHECK_LEVEL = 4

# server catalog version
CATVERSION = $(shell awk '/CATALOG_VERSION_NO/ { print $$3 }' src/include/catalog/catversion.h)

# configure flags

CONFIGURE_FLAGS = \
  --with-tcl \
  --with-perl \
  --with-python \
  --with-pam \
  --with-openssl \
  --with-libxml \
  --with-libxslt \
  --mandir=/usr/share/postgresql/$(MAJOR_VER)/man \
  --docdir=/usr/share/doc/postgresql-doc-$(MAJOR_VER) \
  --sysconfdir=/etc/postgresql-common \
  --datarootdir=/usr/share/ \
  --datadir=/usr/share/postgresql/$(MAJOR_VER) \
  --bindir=/usr/lib/postgresql/$(MAJOR_VER)/bin \
  --libdir=/usr/lib/$(DEB_HOST_MULTIARCH)/ \
  --libexecdir=/usr/lib/postgresql/ \
  --includedir=/usr/include/postgresql/ \
  --with-extra-version=" ($(DEB_VENDOR) $(DEB_VERSION))" \
  --enable-nls \
  --enable-thread-safety \
  --enable-debug \
  --enable-dtrace \
  --disable-rpath \
  --with-uuid=e2fs \
  --with-gnu-ld \
  --with-gssapi \
  --with-ldap \
  --with-pgport=5432 \
  --with-system-tzdata=/usr/share/zoneinfo \
  AWK=mawk \
  MKDIR_P='/bin/mkdir -p' \
  PROVE='/usr/bin/prove' \
  PYTHON=/usr/bin/python3 \
  TAR='/bin/tar' \
  XSLTPROC='xsltproc --nonet' \
  CFLAGS='$(CFLAGS)' \
  LDFLAGS='$(LDFLAGS)'

ifeq ($(call version_ge,9.4),y)
  CONFIGURE_FLAGS += --enable-tap-tests
endif

ifeq ($(call version_ge,9.5),y)
  ifneq ($(findstring $(DEB_HOST_ARCH), alpha),)
    CONFIGURE_FLAGS += --disable-spinlocks
  endif
endif

ifeq ($(call version_ge,10),y)
  CONFIGURE_FLAGS += --with-icu
endif

ifeq ($(call version_ge,11),y)
  # if LLVM is installed, use it
  ifneq ($(wildcard /usr/bin/llvm-config-*),)
    LLVM_CONFIG = $(lastword $(shell ls -v /usr/bin/llvm-config-*))
    LLVM_VERSION = $(subst /usr/bin/llvm-config-,,$(LLVM_CONFIG))
    CONFIGURE_FLAGS += --with-llvm LLVM_CONFIG=$(LLVM_CONFIG) CLANG=/usr/bin/clang-$(LLVM_VERSION)
  else
    LLVM_VERSION = 0.invalid # mute dpkg error on empty version fields in debian/control
  endif
  TEMP_CONFIG = TEMP_CONFIG=$(AUX_MK_DIR)/test-with-jit.conf
endif

ifeq ($(call version_ge,14),y)
  CONFIGURE_FLAGS += --with-lz4
endif

ifeq ($(call version_ge,15),y)
  CONFIGURE_FLAGS += --with-zstd
endif

# Facilitate hierarchical profile generation on amd64 (#730134)
ifeq ($(DEB_HOST_ARCH),amd64)
  CFLAGS += -fno-omit-frame-pointer
endif

# Work around an ICE bug in GCC 11.2.0, see
# https://gcc.gnu.org/bugzilla/show_bug.cgi?id=103395
ifneq ($(findstring $(DEB_HOST_ARCH), armel armhf),)
  CFLAGS+= -DSTAP_SDT_ARG_CONSTRAINT=g
endif

ifeq ($(DEB_HOST_ARCH_OS),linux)
  CONFIGURE_FLAGS += --with-systemd
  CONFIGURE_FLAGS += --with-selinux
endif

ifneq ($(filter pkg.postgresql.cassert,$(DEB_BUILD_PROFILES)),)
  CONFIGURE_FLAGS += --enable-cassert
  GENCONTROL_FLAGS += -Vcassert='$${Newline}$${Newline}This package has been built with cassert enabled.'
endif

# hurd implemented semaphores only recently and tests still fail a lot
# plperl fails on kfreebsd-* (#704802)
ifneq ($(filter hurd kfreebsd,$(DEB_HOST_ARCH_OS)),)
  TEST_FAIL_COMMAND = exit 0
else
  TEST_FAIL_COMMAND = exit 1
endif

# recipes

%:
	dh $@

override_dh_auto_configure:
	dh_auto_configure --builddirectory=build -- $(CONFIGURE_FLAGS)
	# remove pre-built documentation
	rm -fv doc/src/sgml/*-stamp

override_dh_auto_build-indep:
	$(MAKE) -C build/doc all # build man + html

override_dh_auto_build-arch:
	# set MAKELEVEL to 0 to force building submake-generated-headers in src/Makefile.global(.in)
	MAKELEVEL=0 $(MAKE) -C build/src all
	$(MAKE) -C build/doc man # build man only
	$(MAKE) -C build/config all
	$(MAKE) -C build/contrib all
	# build tutorial stuff
	$(MAKE) -C build/src/tutorial NO_PGXS=1

override_dh_auto_install-arch:
	$(MAKE) -C build/doc/src/sgml install-man DESTDIR=$(CURDIR)/debian/tmp
	$(MAKE) -C build/src install DESTDIR=$(CURDIR)/debian/tmp
	$(MAKE) -C build/config install DESTDIR=$(CURDIR)/debian/tmp
	$(MAKE) -C build/contrib install DESTDIR=$(CURDIR)/debian/tmp
	# move SPI examples into server package (they wouldn't be in the doc package in an -A build)
	mkdir -p debian/postgresql-$(MAJOR_VER)/usr/share/doc/postgresql-$(MAJOR_VER)
	mv debian/tmp/usr/share/doc/postgresql-doc-$(MAJOR_VER)/extension debian/postgresql-$(MAJOR_VER)/usr/share/doc/postgresql-$(MAJOR_VER)/examples

override_dh_auto_install-indep:
	$(MAKE) -C build/doc install DESTDIR=$(CURDIR)/debian/tmp

override_dh_makeshlibs:
	dh_makeshlibs -Xusr/lib/postgresql/$(MAJOR_VER)

override_dh_auto_clean:
	rm -rf build

override_dh_installchangelogs:
	dh_installchangelogs HISTORY

override_dh_compress:
	dh_compress -X.source -X.c
	# compress manpages (excluding debian/tmp/)
	gzip -9n $(CURDIR)/debian/*-*/usr/share/postgresql/*/man/man*/*.[137]

override_dh_install-arch:
	dh_install -a

	# link README.Debian.gz to postgresql-common
	mkdir -p debian/postgresql-$(MAJOR_VER)/usr/share/doc/postgresql-$(MAJOR_VER)
	ln -s ../postgresql-common/README.Debian.gz debian/postgresql-$(MAJOR_VER)/usr/share/doc/postgresql-$(MAJOR_VER)/README.Debian.gz

	# assemble perl version of pg_config in libpq-dev
	sed -ne '1,/__DATA__/p' $(AUX_MK_DIR)/pg_config.pl > debian/libpq-dev/usr/bin/pg_config
	LC_ALL=C debian/postgresql-client-$(MAJOR_VER)/usr/lib/postgresql/$(MAJOR_VER)/bin/pg_config >> debian/libpq-dev/usr/bin/pg_config
	LC_ALL=C debian/postgresql-client-$(MAJOR_VER)/usr/lib/postgresql/$(MAJOR_VER)/bin/pg_config --help >> debian/libpq-dev/usr/bin/pg_config
	chmod 755 debian/libpq-dev/usr/bin/pg_config

	# remove actual build path from Makefile.global for reproducibility
	sed -i -e "s!^abs_top_builddir.*!abs_top_builddir = /build/postgresql-$(MAJOR_VER)/build!" \
	       -e "s!^abs_top_srcdir.*!abs_top_srcdir = /build/postgresql-$(MAJOR_VER)/build/..!" \
	       -e 's!-f\(debug\|file\)-prefix-map=[^ ]* !!g' \
	       debian/postgresql-client-$(MAJOR_VER)/usr/lib/postgresql/$(MAJOR_VER)/lib/pgxs/src/Makefile.global

	# these are shipped in the pl packages
	bash -c "rm -v debian/postgresql-$(MAJOR_VER)/usr/share/postgresql/$(MAJOR_VER)/extension/{plperl,plpython,pltcl,*_pl}*"
	bash -c "rm -v debian/postgresql-$(MAJOR_VER)/usr/lib/postgresql/$(MAJOR_VER)/lib/{plperl,plpython,pltcl,*_pl}*"
	bash -c "rm -rfv debian/postgresql-$(MAJOR_VER)/usr/lib/postgresql/$(MAJOR_VER)/lib/bitcode/*{plperl,plpython,pltcl}*"

	# record catversion in a file
	echo $(CATVERSION) > debian/postgresql-$(MAJOR_VER)/usr/share/postgresql/$(MAJOR_VER)/catalog_version

override_dh_install-indep:
	dh_install -i

	if [ -d debian/postgresql-doc-$(MAJOR_VER) ]; then set -e; \
		install -d debian/postgresql-doc-$(MAJOR_VER)/usr/share/doc/postgresql-doc-$(MAJOR_VER)/tutorial; \
		install src/tutorial/*.c src/tutorial/*.source src/tutorial/Makefile src/tutorial/README debian/postgresql-doc-$(MAJOR_VER)/usr/share/doc/postgresql-doc-$(MAJOR_VER)/tutorial; \
	fi

override_dh_auto_test-indep:
	# nothing to do

override_dh_auto_test-arch:
ifeq (, $(findstring nocheck, $(DEB_BUILD_OPTIONS)))
	# when tests fail, print newest log files
	# initdb doesn't like LANG and LC_ALL to contradict, unset LANG and LC_CTYPE here
	# temp-install wants to be invoked from a top-level make, unset MAKELEVEL here
	unset LANG LC_CTYPE MAKELEVEL; ulimit -c unlimited; \
	if ! make -C build check-world \
	  $(TEMP_CONFIG) \
	  PG_TEST_EXTRA='ssl' \
	  PROVE_FLAGS="--verbose"; \
	then \
	    for l in `find build -name 'regression.*' -o -name '*.log' -o -name '*_log_*' | perl -we 'print map { "$$_\n"; } sort { (stat $$a)[9] <=> (stat $$b)[9] } map { chomp; $$_; } <>' | tail -n 10`; do \
		echo "******** $$l ********"; \
		cat $$l; \
	    done; \
	    for c in `find build -name 'core*'`; do \
	        echo "******** $$c ********"; \
	        gdb -batch -ex 'bt full' build/tmp_install/usr/lib/postgresql/$(MAJOR_VER)/bin/postgres $$c || :; \
	    done; \
	    $(TEST_FAIL_COMMAND); \
	fi
endif

override_dh_installdeb-arch:
	dh_installdeb
	# record catversion in preinst
	sed -i -e 's/@CATVERSION@/$(CATVERSION)/' debian/postgresql-$(MAJOR_VER)/DEBIAN/preinst

override_dh_gencontrol:
	# record catversion in .deb control file
	dh_gencontrol -- -Vpostgresql:Catversion=$(CATVERSION) -Vllvm:Version=$(LLVM_VERSION) $(GENCONTROL_FLAGS)
