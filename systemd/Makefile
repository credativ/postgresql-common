install:
	install -d $(DESTDIR)/lib/systemd/system-generators/ $(DESTDIR)/lib/systemd/system/
	install postgresql-generator $(DESTDIR)/lib/systemd/system-generators/
	install -m644 postgresql*.service $(DESTDIR)/lib/systemd/system/
	
	install -d $(DESTDIR)/usr/share/postgresql-common/
	install pg_ctlcluster.sudo $(DESTDIR)/usr/share/postgresql-common/
	install -d $(DESTDIR)/etc/sudoers.d/
	install -m400 postgresql-common.sudoers $(DESTDIR)/etc/sudoers.d/postgresql-common

reload: install
	systemctl daemon-reload
