#
# produce a debian/control file from a debian/control.in
#
# In debian/rules, include /usr/share/postgresql-common/pgxs_debian_control.mk
#
# Author: Dimitri Fontaine <dfontaine@hi-media.com>
#
debian/control: debian/control.in debian/pgversions
	(set -e; \
	VERSIONS=`pg_buildext supported-versions $(CURDIR)`; \
	grep-dctrl -vP PGVERSION $< > $@.pgxs_tmp; \
	for v in $$VERSIONS; do \
		grep-dctrl -P PGVERSION $< | sed -e "s:PGVERSION:$$v:" >> $@.pgxs_tmp; \
	done; \
	mv $@.pgxs_tmp $@) || (rm -f $@.pgxs_tmp; exit 1)

# Rebuild debian/control when clean is invoked
clean: debian/control
.PHONY: debian/control
