# vim: noet
test:
	set -e; for f in `find lib/ -name '*.pm'`; do perl -Ilib -c $$f; done
	prove t/*.t

install:
	mkdir -p -m755 $(DESTDIR)/usr/share/perl5/
	cp -r lib/* $(DESTDIR)/usr/share/perl5/
