POD2MAN=pod2man --center "Debian PostgreSQL infrastructure" -r "Debian"
POD1PROGS=pg_conftool pg_wrapper pg_lsclusters
POD1PROGS_POD=pg_buildext pg_virtualenv
POD8PROGS=pg_ctlcluster pg_createcluster pg_dropcluster pg_upgradecluster pg_updatedicts

all:
	for p in $(POD1PROGS); do $(POD2MAN) --quotes=none --section 1 $$p > $$p.1 || exit 1; done
	for p in $(POD1PROGS_POD); do $(POD2MAN) --quotes=none --section 1 $$p.pod > $$p.1 || exit 1; done
	for p in $(POD8PROGS); do $(POD2MAN) --quotes=none --section 8 $$p > $$p.8 || exit 1; done

clean:
	for p in $(POD1PROGS) $(POD1PROGS_POD); do rm -f $$p.1 || exit 1; done
	for p in $(POD8PROGS); do rm -f $$p.8 || exit 1; done
