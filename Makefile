VALAC:=valac
PRG:=svgcombine
SRC:=svgcombine.vala
PKG:=--pkg gio-2.0 --pkg xmlbird

$(PRG): $(SRC)
	$(VALAC) -o $@ $< $(PKG)

install: $(PRG)
	cp $(PRG) /usr/local/bin/

.PHONY: install


clean:
	rm -f $(PRG)
	
.PHONY: clean

