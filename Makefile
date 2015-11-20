PACKAGE_CHECKOUT := $(shell echo ${PWD})
PACKAGE := github.com/travis-ci/worker
ALL_PACKAGES := $(shell utils/list-packages)

VERSION_VAR := $(PACKAGE).VersionString
VERSION_VALUE ?= $(shell git describe --always --dirty --tags 2>/dev/null)
REV_VAR := $(PACKAGE).RevisionString
REV_VALUE ?= $(shell git rev-parse HEAD 2>/dev/null || echo "'???'")
GENERATED_VAR := $(PACKAGE).GeneratedString
GENERATED_VALUE ?= $(shell date -u +'%Y-%m-%dT%H:%M:%S%z')
COPYRIGHT_VAR := $(PACKAGE).CopyrightString
COPYRIGHT_VALUE ?= $(shell grep -i ^copyright LICENSE | sed 's/^[Cc]opyright //')

GO ?= go
GVT ?= gvt
GOPATH := $(shell echo $${GOPATH%%:*})
GOBUILD_LDFLAGS ?= -ldflags "\
	-X '$(VERSION_VAR)=$(VERSION_VALUE)' \
	-X '$(REV_VAR)=$(REV_VALUE)' \
	-X '$(GENERATED_VAR)=$(GENERATED_VALUE)' \
	-X '$(COPYRIGHT_VAR)=$(COPYRIGHT_VALUE)' \
"
GOXC_BUILD_CONSTRAINTS ?= amd64 linux,amd64 darwin

export GO15VENDOREXPERIMENT

COVERPROFILES := \
	backend-coverage.coverprofile \
	config-coverage.coverprofile \
	context-coverage.coverprofile \
	image-coverage.coverprofile \
	metrics-coverage.coverprofile

%-coverage.coverprofile:
	$(GO) test -v -covermode=count -coverprofile=$@ \
		$(GOBUILD_LDFLAGS) \
		$(PACKAGE)/$(subst -,/,$(subst -coverage.coverprofile,,$@))

.PHONY: all
all: clean deps test

.PHONY: test
test: lintall build fmtpolice .test coverage.html

.PHONY: .test
.test:
	$(GO) test -v

.PHONY: test-no-cover
test-no-cover:
	$(GO) test -v $(GOBUILD_LDFLAGS) $(ALL_PACKAGES)

.PHONY: test-race
test-race:
	$(GO) test -v -race $(GOBUILD_LDFLAGS) $(ALL_PACKAGES)

coverage.html: coverage.coverprofile
	$(GO) tool cover -html=$^ -o $@

coverage.coverprofile: $(COVERPROFILES)
	./utils/fold-coverprofiles $^ > $@
	$(GO) tool cover -func=$@

.PHONY: build
build:
	$(GO) build $(GOBUILD_LDFLAGS)

.PHONY: crossbuild
crossbuild:
	$(GOXC) -bc='$(GOXC_BUILD_CONSTRAINTS)' -d=.build/ -pv=$(VERSION_VALUE)

.PHONY: clean
clean:
	./utils/clean

.PHONY: distclean
distclean: clean
	rm -f vendor/.deps-fetched

.PHONY: deps
deps: vendor/.deps-fetched

vendor/.deps-fetched:
	$(GVT) rebuild
	touch $@

.PHONY: annotations
annotations:
	@git grep -E '(TODO|FIXME|XXX):' | grep -v -E 'Makefile|vendor/'

.PHONY: fmtpolice
fmtpolice:
	./utils/fmtpolice

.PHONY: lintall
lintall:
	./utils/lintall

.PHONY:  package
package:
	./utils/pkg/pkg_run
