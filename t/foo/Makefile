TAR = foo_123.orig.tar.gz

test: $(TAR)
	cd foo-123 && echo y | EDITOR=true dh_make_pgxs
	cd foo-123 && dpkg-buildpackage -us -uc

tar $(TAR):
	tar cfz $(TAR) foo-123/

clean:
	rm -f *.*
	rm -rf foo-123/build-* foo-123/debian foo-123/*.o*
