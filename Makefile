all:
	@echo Done. Call make install
install:
	cp imgmount.pl /usr/local/bin/imgmount
	ln -s /usr/local/bin/imgmount /usr/local/bin/imgumount
uninstall:
	rm /usr/local/bin/imgumount /usr/local/bin/imgmount
