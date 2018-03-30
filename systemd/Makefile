install:
	install -d $(DESTDIR)/lib/systemd/system-generators/ $(DESTDIR)/lib/systemd/system/
	install postgresql-generator $(DESTDIR)/lib/systemd/system-generators/
	install -m644 postgresql*.service $(DESTDIR)/lib/systemd/system/
	install -d $(DESTDIR)/usr/lib/systemd/user/
	install -m644 user/postgresql*.service $(DESTDIR)/usr/lib/systemd/user/

reload: install
	systemctl daemon-reload
