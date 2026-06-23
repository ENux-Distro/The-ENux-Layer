# The ENux Layer
#
# The bin/, libexec/, and etc/ trees are the source (POSIX sh + config).
# sbin/init is a build artifact: it is the static binary from the separate
# init.c repo, copied in here. Point INIT_SRC at your init.c checkout.
#
#   make            build init and place it in sbin/
#   make check      syntax-check every shell script
#   make install    install the /enux tree into DESTDIR (for an ISO rootfs)
#   make clean      remove the built init binary

INIT_SRC ?= ../init.c
DESTDIR  ?=
PREFIX   ?= /enux

BIN     := bin/enux bin/layer bin/pmm bin/debinstall
LIBEXEC := libexec/layer-enable libexec/layer-disable libexec/layer-enter \
           libexec/cross-dispatch

.PHONY: all init check install clean

all: init

# Build init from the separate init.c repo and drop it in sbin/. The Layer
# tooling works without it (manual `layer enter` / `pmm`); init is only
# needed for boot-time layer enablement.
# Always re-run the (incremental) init.c build and re-copy, so sbin/init
# can't go stale against init.c source changes - a plain file target with
# no prerequisites would never rebuild once it exists.
init:
	@test -d "$(INIT_SRC)" || { \
		echo "init.c not found at $(INIT_SRC) - set INIT_SRC=/path/to/init.c" >&2; \
		exit 1; }
	$(MAKE) -C "$(INIT_SRC)"
	install -D -m 0755 "$(INIT_SRC)/build/init" sbin/init

check:
	@for f in $(BIN) $(LIBEXEC); do \
		sh -n "$$f" && echo "ok: $$f" || exit 1; \
	done
	@if command -v shellcheck >/dev/null 2>&1; then \
		shellcheck $(BIN) $(LIBEXEC); \
	else \
		echo "(shellcheck not installed; skipped)"; \
	fi

# Lay the full /enux tree into DESTDIR. For an ISO: make install DESTDIR=$ROOTFS
install:
	install -d "$(DESTDIR)$(PREFIX)/bin" "$(DESTDIR)$(PREFIX)/libexec" \
	           "$(DESTDIR)$(PREFIX)/sbin" "$(DESTDIR)$(PREFIX)/etc" \
	           "$(DESTDIR)$(PREFIX)/layer" "$(DESTDIR)$(PREFIX)/cross/bin"
	install -m 0755 $(BIN)     "$(DESTDIR)$(PREFIX)/bin/"
	install -m 0755 $(LIBEXEC) "$(DESTDIR)$(PREFIX)/libexec/"
	install -m 0644 etc/os-release "$(DESTDIR)$(PREFIX)/etc/"
	install -D -m 0644 etc/enux.sh "$(DESTDIR)/etc/profile.d/enux.sh"
	@# Never clobber an existing enux.conf - it holds the user's exec_order.
	@if [ ! -f "$(DESTDIR)$(PREFIX)/etc/enux.conf" ]; then \
		install -m 0644 etc/enux.conf "$(DESTDIR)$(PREFIX)/etc/enux.conf"; \
	else \
		echo "keeping existing $(DESTDIR)$(PREFIX)/etc/enux.conf"; \
	fi
	@if [ -x sbin/init ]; then \
		install -m 0755 sbin/init "$(DESTDIR)$(PREFIX)/sbin/init"; \
	else \
		echo "warning: sbin/init not built - run 'make init' for boot support" >&2; \
	fi

clean:
	rm -f sbin/init
