PREFIX ?= $(HOME)/.local
BINDIR ?= $(PREFIX)/bin
MANDIR ?= $(PREFIX)/share/man
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

uninstall:
	rm -f -- "$(DESTDIR)$(BINDIR)/pcc" "$(DESTDIR)$(MANDIR)/man1/pcc.1"

man:
	command -v "$(PANDOC)" >/dev/null || { echo 'pandoc is required to regenerate pc-command-center.1' >&2; exit 1; }
	"$(PANDOC)" --standalone --to man --metadata title=pcc --metadata section=1 --metadata date="$$(date +%Y-%m-%d)" readme.md --output=pc-command-center.1
	sed -i '1i.\\" Generated from readme.md using pandoc; regenerate with make man.' pc-command-center.1

package:
	./packaging/build-deb.sh "$(VERSION)" dist
