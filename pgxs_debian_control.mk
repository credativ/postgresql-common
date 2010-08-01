#
# produce a debian/control file from a debian/control.in
#
# In debian/rules, include /usr/share/postgresql-common/pgxs_debian_control.mk
# build: debian/control
#
# Author: Dimitri Fontaine <dfontaine@hi-media.com>
#
debian/control: debian/control.in debian/pgversions
	grep-dctrl -vP PGVERSION $< > $@

	for v in `pg_buildext supported-versions $(SRCDIR)`; \
        do                                         \
		grep -q "^$$v" debian/pgversions   \
		&& grep-dctrl -P PGVERSION $<      \
		| sed -e "s:PGVERSION:$$v:" >> $@; \
	done
