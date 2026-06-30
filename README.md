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
/enux/bin/          enux, layer, pmm, install-xfce, Start-XFCE, nm-tui  (user commands)
/enux/libexec/      layer-enable, layer-disable, layer-enter,
                    layer-chroot, cross-dispatch, layer-cross             (mechanics)
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

### `layer` — enter a layer

```
layer enable <name>                          mount the layer for use
layer disable <name>                         tear the layer's mounts down
layer enter [--global] [--user|--gui] <name> [cmd]
layer list                                   show layers and mount state
```

`layer enter` has three modes controlled by flags:

- *(no flag)* — root chroot. Used for package installs, daemon setup, system
  writes. Standard `apt install`, `pacman -S`, etc. use this path.
- `--user` — bwrap (pivot_root) session as the real user. Not a chroot, so
  cross commands inside it can nest their own namespace (rpm, dnf, apk all
  find their own `/etc` and `/usr/lib`).
- `--gui` — chroot + setpriv session as the real user. Xorg.wrap keeps its
  setuid bit so the X server can open `/dev/tty0` and DRM. Use for desktop
  sessions. Combine with `--user` to get the full flag set (`--global --user
  --gui`) — `--gui` takes effect for the X server launch.
- `--global` — additionally shares `/home`, drives, D-Bus, and the live
  `/enux` tree from the base into the layer, so a desktop session operates on
  the real ENux root rather than the layer's isolated copies.

`layer-enable` self-binds the layer, brings in `/proc`, `/sys`, `/dev`,
`/dev/pts`, the X11 socket, and the udev runtime database. `/home` is always
shared into every enabled layer so cross commands run as the real user with
their own home directory and `~/.Xauthority` in scope.

### `pmm` — packages, any distro

```
pmm install <pkg...>                   into the default (first) layer
pmm install layer:<name> <pkg...>      into a specific layer
pmm remove|update|upgrade|search|list ...
```

`pmm` detects each layer's native package manager (pacman, apt, dnf, apk,
xbps, zypper, emerge) and translates the operation, so the same command works
everywhere. `pmm remove <pkg>` removes it from every layer that has it.

### Cross commands — package managers and more by name

Every command that lives in a layer and is absent from the base gets a
symlink in `/enux/cross/bin/` (on `PATH`). Typing the command name routes it
to its layer automatically:

```sh
pacman -Syu          # → arch layer
apt search vim       # → debian layer
emerge --sync        # → gentoo layer
sudo apt install foo # → debian layer (privileged write)
```

After any install or remove, the cross index rebuilds automatically and
`hash -r` is called in the current shell (via a function wrapper in
`/etc/profile.d/enux.sh`), so newly installed commands are usable without
re-logging in.

Cross execution is handled by **layer-chroot** — a static C binary with the
`cap_sys_chroot` file capability. It runs the command in the layer's full
view as the calling user (no sudo, no user namespace), and works even when
called from inside another chroot (e.g. the XFCE desktop session). Package
managers that need root still require `sudo`; everything else runs as you.

### Desktop helpers

```
install-xfce   install XFCE into the Debian layer (run once after enux install debian)
Start-XFCE     launch the XFCE desktop (written by install-xfce)
nm-tui         NetworkManager text UI (auto-starts NM and wpa_supplicant)
```

## Building

```sh
make                              # build layer-chroot (static) + init
make layer-chroot                 # build only layer-chroot
make check                        # syntax-check all shell scripts
make install DESTDIR="$ROOT"      # lay /enux into a rootfs
```

`make install` sets `cap_sys_chroot=ep` on `layer-chroot` (needs root and an
xattr-capable filesystem). When building an ISO, `build-iso.sh` sets the
capability before `mksquashfs` so it is carried into the image via the
`security.capability` xattr (`mksquashfs -xattrs`).

The init component (`sbin/init`) is the static binary from the separate
[init.c](https://github.com/ENux-Distro/init.c) repo. `INIT_SRC` defaults to
`../init.c`. The tooling is fully usable without init for manual layer work;
init is only required for boot-time layer enablement.

## Putting it in an ISO

See [ISO.md](ISO.md) for the full live-ISO procedure, including the mandatory
step of disabling every layer before `mksquashfs` (enabled layers bind-mount
the host's live `/proc` and `/dev`, which must never be baked into an image).

## Status

More Stable. The commands work and are tested on read-only squashfs roots and
in a booted live ISO. Cross-layer command execution, package managers by name,
and the XFCE desktop session are all verified. See [CONTRIBUTING.md](CONTRIBUTING.md) to help.

## License

GPL-3.0. See [LICENSE](LICENSE).
