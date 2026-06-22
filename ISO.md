# Putting The ENux Layer in an ISO

How to bake The ENux Layer into a live ISO's squashfs root.

## 1. Build and install into the ISO rootfs

With your base rootfs unpacked at `$ROOTFS`:

```sh
make INIT_SRC=/path/to/init.c        # build sbin/init
make install DESTDIR="$ROOTFS"       # lay /enux into the rootfs
```

This installs:

```
$ROOTFS/enux/bin/{enux,layer,pmm}
$ROOTFS/enux/libexec/layer-{enable,disable,enter}
$ROOTFS/enux/sbin/init
$ROOTFS/enux/etc/{enux.conf,os-release}
$ROOTFS/enux/layer/
```

## 2. Optionally pre-install layers

Ship the ISO with layers already present by writing into the image's
`/enux/layer` from the host:

```sh
LAYER_DIR="$ROOTFS/enux/layer" \
BIN_DIR="$ROOTFS/enux/bin" \
LIBEXEC_DIR="$ROOTFS/enux/libexec" \
    "$ROOTFS/enux/bin/enux" install arch
```

The ENux base system itself (the `enux` layer in `exec_order`) is the
`$ROOTFS` you are building — it does not go under `/enux/layer`.

## 3. CRITICAL: disable every layer before squashing

`layer-enable` bind-mounts the host's live `/proc`, `/sys`, and `/dev`
into a layer. Running `mksquashfs` while those are active bakes live host
PIDs and device nodes into the image. Always tear down first:

```sh
for d in "$ROOTFS"/enux/layer/*/; do
    [ -d "$d" ] || continue
    LAYER_DIR="$ROOTFS/enux/layer" \
        "$ROOTFS/enux/bin/layer" disable "$(basename "$d")" || true
done

# Refuse to continue if anything under the rootfs is still mounted.
grep " $ROOTFS/enux/layer" /proc/self/mountinfo && {
    echo "refusing to squash: layers still mounted" >&2; exit 1; }
```

## 4. Build the squashfs

ENux relies on xattrs, so `-xattrs` is mandatory:

```sh
mksquashfs "$ROOTFS" filesystem.squashfs -comp zstd -xattrs -noappend
```

## 5. Runtime

A booted live ISO mounts this squashfs read-only. The Layer tooling works
unmodified on a read-only root: `layer-enable` self-binds the layer and
brings up `/proc`/`/sys`/`/dev`, writes to the squashfs are correctly
rejected, and the layer stays usable. For a writable system, overlay a
tmpfs (or persistent) upper over the squashfs lower — that overlay setup
is the live-ISO build's responsibility, not the Layer's.

## Not yet wired

`init.c` boots and reads `enux.conf`, but its layer-enable path still
expects `/enux/libexec/layer-repair` and `layer-apply`, which do not exist
yet. Until those land, an ISO can ship and run the Layer tooling manually
(`layer enter`, `pmm`, `enux`), but boot-time automatic layer enablement
is incomplete.
