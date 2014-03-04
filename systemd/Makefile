install:
	install -d $(DESTDIR)/lib/systemd/system-generators/ $(DESTDIR)/lib/systemd/system/
	install postgresql-generator $(DESTDIR)/lib/systemd/system-generators/
	install -m644 postgresql*.service $(DESTDIR)/lib/systemd/system/

reload: install
	systemctl daemon-reload
