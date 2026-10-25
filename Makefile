PREFIX ?= $(HOME)/.local
BINDIR ?= $(PREFIX)/bin
MANDIR ?= $(PREFIX)/share/man
DOCDIR ?= $(PREFIX)/share/doc/pc-command-center
DESTDIR ?=
PANDOC ?= pandoc
VERSION := $(shell sed -n 's/^VERSION="\([0-9][^"]*\)"/\1/p' pc-command-center.sh)
PACKAGE := pc-command-center_$(VERSION)_all.deb

.PHONY: help install uninstall man package

help:
	@printf '%s\n' 'Targets:' '  make install [PREFIX=~/.local]' '  make uninstall [PREFIX=~/.local]' '  make man (requires pandoc)' '  make package (requires dpkg-deb)'

install:
	install -D -m 755 pc-command-center.sh "$(DESTDIR)$(BINDIR)/pcc"
	install -D -m 644 pc-command-center.1 "$(DESTDIR)$(MANDIR)/man1/pcc.1"
	install -D -m 644 examples/profiles/daily.conf "$(DESTDIR)$(DOCDIR)/examples/profiles/daily.conf"
	install -D -m 644 examples/profiles/development.conf "$(DESTDIR)$(DOCDIR)/examples/profiles/development.conf"
	install -D -m 644 examples/profiles/low-power.conf "$(DESTDIR)$(DOCDIR)/examples/profiles/low-power.conf"

uninstall:
	rm -f -- "$(DESTDIR)$(BINDIR)/pcc" "$(DESTDIR)$(MANDIR)/man1/pcc.1"
	rm -f -- "$(DESTDIR)$(DOCDIR)/examples/profiles/daily.conf" "$(DESTDIR)$(DOCDIR)/examples/profiles/development.conf" "$(DESTDIR)$(DOCDIR)/examples/profiles/low-power.conf"

man:
	command -v "$(PANDOC)" >/dev/null || { echo 'pandoc is required to regenerate pc-command-center.1' >&2; exit 1; }
	"$(PANDOC)" --standalone --to man --metadata title=pcc --metadata section=1 --metadata date="$$(date +%Y-%m-%d)" readme.md --output=pc-command-center.1
	sed -i '1i.\\" Generated from readme.md using pandoc; regenerate with make man.' pc-command-center.1

package:
	./packaging/build-deb.sh "$(VERSION)" dist
