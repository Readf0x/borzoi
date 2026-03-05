PREFIX ?= /usr/local
BINDIR ?= $(PREFIX)/bin
MANDIR ?= $(PREFIX)/share/man
BASHCOMPDIR ?= $(PREFIX)/share/bash-completion/completions
ZSHCOMPDIR ?= $(PREFIX)/share/zsh/site-functions
FISHCOMPDIR ?= $(PREFIX)/share/fish/vendor_completions.d

VERSIONSTR ?= borzoi version 0.1.0, built from commit $$(git rev-parse --short HEAD) on $$(git branch --show-current)

build:
	odin build src -out:borzoi \
		-define:VERSION="$(VERSIONSTR)"

debug:
	odin build src -debug -out:borzoi \
		-define:VERSION="$(VERSIONSTR)"

install: build
	install -Dm755 borzoi "$(DESTDIR)$(BINDIR)/borzoi"
	install -Dm644 static/borzoi.1 "$(DESTDIR)$(MANDIR)/man1/borzoi.1"
	install -Dm644 static/borzoi.bash "$(DESTDIR)$(BASHCOMPDIR)/borzoi"
	install -Dm644 static/borzoi.zsh "$(DESTDIR)$(ZSHCOMPDIR)/_borzoi"
	install -Dm644 static/borzoi.fish "$(DESTDIR)$(FISHCOMPDIR)/borzoi.fish"
