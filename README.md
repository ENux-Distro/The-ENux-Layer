# The ENux Layer

The ENux Layer lets multiple Linux distributions coexist on one system and
share a unified package-management front end. It is the core of the
ENux 6.x lineup — inspired by [Bedrock Linux](https://bedrocklinux.org),
but reimplemented from scratch so ENux carries no upstream dependency, and
designed from the start to work in chroot, container, and non-PID-1
environments (live ISOs included).

A *layer* is a distribution's root filesystem under `/enux/layer/<name>`.
You install layers, enter them, and install packages into them through one
consistent set of commands, regardless of which distro each layer runs.

## Layout

```
/enux/bin/          enux, layer, pmm                    (user commands)
/enux/libexec/      layer-enable, layer-disable,
                    layer-enter, cross-dispatch          (mechanics)
/enux/sbin/init     init.c — PID 1 (built separately; see Building)
/enux/cross/        cross-command dir (per-command symlinks + index)
/enux/etc/          enux.conf, os-release, enux.sh
/enux/layer/<name>/ installed layer rootfilesystems
```

## Commands

### `enux` — manage layers

```
enux install <name> [url-or-tarball]   fetch + install a layer
enux remove <name>                     disable and delete a layer
enux list                              list installed layers
enux show <name>                       details for one layer
enux set-exec-order <name> [name...]   set priority order
enux exec <command> [args...]          run in the first layer in order
enux cross                             rebuild the cross-command dir
enux configure <name>                  (re)set up a layer's repos/keys
```

Known layers have a built-in rootfs source, so `enux install fedora` just
works: `arch`, `alpine`, `fedora`, `debian`, `ubuntu`, `opensuse`, `void`,
`gentoo`, `rockylinux`, `centos`. Rootfs resolution prefers a mirror's
`latest` alias when one exists, otherwise the newest upload.

On install, each layer is also configured for immediate use (Arch keyring +
mirrorlist, Alpine/Debian/openSUSE repos), and the ENux tooling
(`/enux/bin`, `/enux/cross`, `/enux/libexec`) is copied into it with its
`/etc/profile` extended so the commands are on `PATH` inside the layer.

### `layer` — enter a layer (the strat clone)

```
layer enable <name>                    mount the layer for use
layer disable <name>                   tear the layer's mounts down
layer enter [--global] <name> [cmd]    enable + chroot in (shell if no cmd)
layer list                             show layers and mount state
```

`layer-enable` self-binds the layer, brings in `/proc`, `/sys`, `/dev`, the
X11 socket and udev runtime, and (with `--global`) shares the base system's
`/home`, drives, and runtime so a layer's desktop operates on the real ENux
root.

### `pmm` — packages, any distro

```
pmm install <pkg...>                   into the default (first) layer
pmm install layer:<name> <pkg...>      into a specific layer
pmm remove|update|upgrade|search|list ...
```

`pmm` detects each layer's native package manager (pacman, apt, dnf, apk,
xbps, zypper, emerge) and translates the operation, so the same command
works everywhere. `pmm remove <pkg>` removes it from every layer that has
it.

## Building

The Layer tooling is POSIX shell and needs no build step. The init
component (`sbin/init`) is the static binary from the separate
[init.c](https://github.com/ENux-Distro/init.c) repo:

```sh
make INIT_SRC=/path/to/init.c     # builds init, places it in sbin/init
make check                        # syntax-check the shell scripts
make install DESTDIR="$ROOT"      # lay /enux into a rootfs
```

`INIT_SRC` defaults to `../init.c`. The tooling is fully usable without
init for manual layer work; init is only required for boot-time layer
enablement.

## Putting it in an ISO

See [ISO.md](ISO.md) for the full live-ISO procedure, including the
mandatory step of disabling every layer before `mksquashfs` (enabled layers
bind-mount the host's live `/proc` and `/dev`, which must never be baked
into an image).

## Status

Early alpha. The commands work and are tested on read-only squashfs roots
and in a booted live ISO. See [CONTRIBUTING.md](CONTRIBUTING.md) to help.

## License

GPL-3.0. See [LICENSE](LICENSE).
