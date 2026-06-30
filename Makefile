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

CC       ?= cc
# layer-chroot is built static and depends only on libc: it runs in the base
# AND, when a cross command is invoked from inside another layer's chroot, as a
# base binary reached via the /enux bind - a dynamic build would try the wrong
# layer's loader there. Static side-steps that entirely.
CFLAGS   ?= -O2 -Wall -Wextra

BIN     := bin/enux bin/layer bin/pmm
# Shell scripts only (these are what `make check` syntax-checks).
LIBEXEC := libexec/layer-enable libexec/layer-disable libexec/layer-enter \
           libexec/cross-dispatch libexec/layer-provision libexec/layer-cross
# Compiled helper (build artifact, not a shell script). cap_sys_chroot is set
# at install/ISO-build time, not here.
LIBEXEC_BIN := libexec/layer-chroot

.PHONY: all init layer-chroot check install clean

all: init layer-chroot

# layer-chroot: a cap_sys_chroot helper that runs a command in a layer as the
# calling user with no sudo. See src/layer-chroot/layer-chroot.c.
layer-chroot: $(LIBEXEC_BIN)
$(LIBEXEC_BIN): src/layer-chroot/layer-chroot.c
	$(CC) -static $(CFLAGS) -o $@ $<

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
	@# layer-chroot + its cap_sys_chroot capability. Needs root and an xattr-capable
	@# filesystem; mksquashfs -xattrs then carries the cap into the image.
	@if [ -x libexec/layer-chroot ]; then \
		install -m 0755 libexec/layer-chroot "$(DESTDIR)$(PREFIX)/libexec/layer-chroot"; \
		setcap cap_sys_chroot=ep "$(DESTDIR)$(PREFIX)/libexec/layer-chroot" \
			&& echo "set cap_sys_chroot on layer-chroot" \
			|| echo "warning: setcap on layer-chroot failed - run as root: setcap cap_sys_chroot=ep $(DESTDIR)$(PREFIX)/libexec/layer-chroot" >&2; \
	else \
		echo "warning: libexec/layer-chroot not built - run 'make layer-chroot' (cross falls back to bwrap without it)" >&2; \
	fi
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
	rm -f sbin/init libexec/layer-chroot
