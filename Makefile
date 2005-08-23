.PHONY: install

install: 	
	mkdir -p $(DESTDIR)/usr/bin
	cp -a release_pjl/* $(DESTDIR)/usr/bin
	mkdir -p $(DESTDIR)/usr/share/print-utils-pfeifle-kanotix/
	install -m755 vampire/functions-to-get-drivers.sh $(DESTDIR)/usr/share/print-utils-pfeifle-kanotix/
	install -m755 vampire/print-utils-run.sh $(DESTDIR)/usr/bin/
	install -m755 vampire/print-utils-get-functions.sh $(DESTDIR)/usr/bin/
	install -m755 vampire/print-utils-get-help.sh $(DESTDIR)/usr/bin/
