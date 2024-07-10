all: lint test build

ci: test build

.PHONY: all ci

#################################################
# Determine the type of `push` and `version`
#################################################

# Set V to 1 for verbose output from the Makefile
Q=$(if $V,,@)
PREFIX?=
SRC=$(shell find . -type f -name '*.go')
GOOS_OVERRIDE ?=
CGO_OVERRIDE ?= CGO_ENABLED=0
OUTPUT_ROOT=output/

GORELEASER_BUILD_ID?=default
ifdef DEBUG
	GORELEASER_BUILD_ID=debug
endif


.PHONY: all

#########################################
# Bootstrapping
#########################################

bootstra%:
	$Q curl -sSfL https://raw.githubusercontent.com/golangci/golangci-lint/master/install.sh | sh -s -- -b $$(go env GOPATH)/bin latest
	$Q go install golang.org/x/vuln/cmd/govulncheck@latest
	$Q go install gotest.tools/gotestsum@latest
	$Q go install golang.org/x/tools/cmd/goimports@latest
	$Q go install github.com/goreleaser/goreleaser@latest

.PHONY: bootstra%

#########################################
# Build
#########################################

build: $(PREFIX)bin/step
	@echo "Build Complete!"

$(PREFIX)bin/step:
	$Q mkdir -p $(@D)
	$Q $(GOOS_OVERRIDE) $(CGO_OVERRIDE) goreleaser build \
		--id $(GORELEASER_BUILD_ID) \
	   	--snapshot \
		--single-target \
	   	--clean \
		--output $(PREFIX)bin/step

.PHONY: build

#########################################
# Test
#########################################

test:
	$Q $(CGO_OVERRIDE) $(GOFLAGS) gotestsum -- -coverprofile=coverage.out -short -covermode=atomic ./...

race:
	$Q $(CGO_OVERRIDE) $(GOFLAGS) gotestsum -- -race ./...

.PHONY: test race

integrate: integration

integration: bin/step
	$Q $(CGO_OVERRIDE) gotestsum -- -tags=integration ./integration/...

.PHONY: integrate integration

#########################################
# Linting
#########################################

fmt:
	$Q goimports -local github.com/golangci/golangci-lint -l -w $(SRC)

lint: golint govulncheck

golint: SHELL:=/bin/bash
golint:
	$Q LOG_LEVEL=error golangci-lint run --config <(curl -s https://raw.githubusercontent.com/smallstep/workflows/master/.golangci.yml) --timeout=30m

govulncheck:
	$Q govulncheck ./...

.PHONY: fmt lint golint govulncheck

#########################################
# Install
#########################################

INSTALL_PREFIX?=/usr/local/

install: $(PREFIX)bin/step
	$Q mkdir -p $(INSTALL_PREFIX)bin/
	$Q install $(PREFIX)bin/step $(DESTDIR)$(INSTALL_PREFIX)bin/step

uninstall:
	$Q rm -f $(DESTDIR)$(INSTALL_PREFIX)/bin/step

.PHONY: install uninstall

#########################################
# Clean
#########################################

clean:
	$Q rm -f bin/step
	$Q rm -rf dist

.PHONY: clean

#################################################
# Build statically compiled step binary for various operating systems
#################################################

BINARY_OUTPUT=$(OUTPUT_ROOT)binary/

define BUNDLE_MAKE
	# $(1) -- Go Operating System (e.g. linux, darwin, windows, etc.)
	# $(2) -- Go Architecture (e.g. amd64, arm, arm64, etc.)
	# $(3) -- Go ARM architectural family (e.g. 7, 8, etc.)
	# $(4) -- Parent directory for executables generated by 'make'.
	$(q) GOOS=$(1) GOARCH=$(2) GOARM=$(3) PREFIX=$(4) make $(4)bin/step
endef

binary-linux-amd64:
	$(call BUNDLE_MAKE,linux,amd64,,$(BINARY_OUTPUT)linux-amd64/)

binary-linux-arm64:
	$(call BUNDLE_MAKE,linux,arm64,,$(BINARY_OUTPUT)linux-arm64/)

binary-linux-armv7:
	$(call BUNDLE_MAKE,linux,arm,7,$(BINARY_OUTPUT)linux-armv7/)

binary-linux-mips:
	$(call BUNDLE_MAKE,linux,mips,,$(BINARY_OUTPUT)linux-mips/)

binary-darwin-amd64:
	$(call BUNDLE_MAKE,darwin,amd64,,$(BINARY_OUTPUT)darwin-amd64/)

binary-darwin-arm64:
	$(call BUNDLE_MAKE,darwin,amd64,,$(BINARY_OUTPUT)darwin-arm64/)

binary-windows-amd64:
	$(call BUNDLE_MAKE,windows,amd64,,$(BINARY_OUTPUT)windows-amd64/)

.PHONY: binary-linux-amd64 binary-linux-arm64 binary-linux-armv7 binary-linux-mips binary-darwin-amd64 binary-darwin-arm64 binary-windows-amd64
