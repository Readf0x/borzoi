PREFIX ?= /usr/local
BINDIR ?= $(PREFIX)/bin

VERSIONSTR ?= borzoi version 0.1.0, built from commit $$(git rev-parse --short HEAD) on $$(git branch --show-current)

build:
	odin build src -out:borzoi \
		-define:VERSION="$(VERSIONSTR)"

install: build
	install -Dm755 borzoi "$(DESTDIR)$(BINDIR)/borzoi"
