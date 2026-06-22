# The ENux Layer

The ENux Layer lets multiple Linux distributions coexist on one system and
share a unified package-management front-end. It is the core of the
ENux 6.x lineup — heavily inspired by [Bedrock Linux](https://bedrocklinux.org),
but reimplemented from scratch so ENux carries no upstream dependency, and
designed from day one to work in chroot, container, and non-PID-1
environments (live ISOs included).

A *layer* is a distribution's root filesystem under `/enux/layer/<name>`.
You install layers, enter them, and install packages into them through one
consistent set of commands, regardless of which distro each layer runs.

## Layout

```
/enux/bin/enux        layer lifecycle manager (install/remove/list/...)
/enux/bin/layer       enable/disable/enter a layer (the strat clone)
/enux/bin/pmm         unified package manager front-end
/enux/libexec/        mount/chroot mechanics behind `layer`
/enux/sbin/init       init.c — PID 1 (built separately; see Building)
/enux/etc/enux.conf   configuration (init + layer settings)
/enux/layer/<name>/   installed layer rootfilesystems
```

## Commands

### `enux` — manage layers

```sh
enux install <name> [url-or-tarball]   # fetch + install a layer
enux remove <name>                     # disable and delete a layer
enux list                              # list installed layers
enux show <name>                       # details for one layer
enux set-exec-order <name> [name...]   # set priority order
enux exec <command> [args...]          # run in the first layer in order
```

Known layers (`arch`, `alpine`, `fedora`, and other linuxcontainers
distros: `debian`, `ubuntu`, `rockylinux`, `centos`, `opensuse`,
`voidlinux`) have a built-in rootfs source — `enux install fedora` just
works. Rootfs resolution prefers a mirror's `latest` alias when one
exists, otherwise it grabs the newest uploaded tarball.

### `layer` — enter a layer

```sh
layer enable <name>                    # mount the layer for use
layer enter <name> [command [args]]    # enable + chroot in (shell if no cmd)
layer disable <name>                   # tear the layer's mounts down
layer list                             # show layers and mount state
```

### `pmm` — packages, any distro

```sh
pmm install <pkg...>                   # into the default (first) layer
pmm install layer:<name> <pkg...>      # into a specific layer
pmm remove|update|upgrade|search|list ...
```

`pmm` detects each layer's native package manager (pacman, apt, dnf, apk,
xbps, zypper, emerge) and translates the operation, so the same command
works everywhere.

## Building

The Layer tooling is POSIX shell and needs no build step. The init
component (`sbin/init`) is the static binary from the separate
[init.c](https://github.com/ENux-Distro/init.c) repo:

```sh
make INIT_SRC=/path/to/init.c     # builds init, places it in sbin/init
make check                        # syntax-check the shell scripts
```

`INIT_SRC` defaults to `../init.c`. The tooling is fully usable without
init for manual layer work; init is only required for boot-time layer
enablement.

## Putting it in an ISO

```sh
make install DESTDIR="$ROOTFS"    # lay /enux into your ISO rootfs
```

See [ISO.md](ISO.md) for the full procedure, including the mandatory step
of disabling every layer before running `mksquashfs` — enabled layers
bind-mount the host's live `/proc` and `/dev`, which must never be baked
into an image.

## Status

Early alpha. The commands (`enux`, `layer`, `pmm`) work and are tested on
read-only squashfs roots. Boot-time automatic layer enablement via init.c
is not yet wired — see [ISO.md](ISO.md).
