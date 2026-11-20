#!/bin/sh
# Build fake08 for one target. Usage: build.sh <target>
# linux-x86_64: built inside a Debian 12 (bookworm) amd64 root so the core only needs glibc 2.36.
#   DEBIAN_AMD64_ROOT   path of that root (default /chroot/bookworm-amd64); it needs build-essential and git.
#   Needs sudo for chroot. On CI, run this script inside a debian:12 container instead and set
#   IN_DEBIAN12=1 to build directly.
# linux-arm64: cross-compiled against a Debian 12 arm64 sysroot (SYSROOT, default /chroot/bookworm-arm64).
HERE=$(cd "$(dirname "$0")" && pwd)
. "$HERE/../../scripts/common.sh"
. "$HERE/recipe.env"

TARGET=${1:?usage: build.sh <target>}
check_target "$TARGET"

SRC=$WORK_DIR/$CORE
fetch_source "$UPSTREAM_URL" "$UPSTREAM_REV" "$SRC"
BUILD_DIR=$SRC/$MAKE_DIR

case "$TARGET" in
    linux-x86_64)
        STRIP=strip
        SUDO=${SUDO:-sudo}
        if [ "${IN_DEBIAN12:-0}" = 1 ]; then
            make -C "$BUILD_DIR" clean >/dev/null 2>&1 || true
            make -C "$BUILD_DIR" -j"$(nproc)" platform=unix
        else
            ROOT=${DEBIAN_AMD64_ROOT:-/chroot/bookworm-amd64}
            $SUDO mkdir -p "$ROOT/mnt/work"
            $SUDO mount --bind "$WORK_DIR" "$ROOT/mnt/work"
            trap "$SUDO umount \"$ROOT/mnt/work\""  EXIT
            $SUDO chroot "$ROOT" /bin/sh -c "make -C /mnt/work/$CORE/$MAKE_DIR clean >/dev/null 2>&1; make -C /mnt/work/$CORE/$MAKE_DIR -j$(nproc) platform=unix"
            # The chroot runs make as root; hand the outputs back so the host-side strip and packaging work.
            $SUDO chown -R "$(id -u):$(id -g)" "$SRC"
        fi
        ;;
    linux-arm64)
        TRIPLE=aarch64-linux-gnu
        STRIP=$TRIPLE-strip
        SYSROOT=${SYSROOT:-/chroot/bookworm-arm64}
        INC="--sysroot=$SYSROOT -isystem $SYSROOT/usr/include/$TRIPLE -isystem $SYSROOT/usr/include"
        # The sysroot's libm.so is an absolute symlink that dangles on the host; point a shim at the real library.
        SHIM=$WORK_DIR/shims-$TARGET
        mkdir -p "$SHIM"
        ln -sf "$SYSROOT/lib/$TRIPLE/libm.so.6" "$SHIM/libm.so"
        LIB="--sysroot=$SYSROOT -L$SHIM -L$SYSROOT/usr/lib/$TRIPLE -L$SYSROOT/lib/$TRIPLE -L$SYSROOT/usr/lib/gcc/$TRIPLE/12 -Wl,-rpath-link,$SYSROOT/usr/lib/$TRIPLE:$SYSROOT/lib/$TRIPLE"
        make -C "$BUILD_DIR" clean >/dev/null 2>&1 || true
        make -C "$BUILD_DIR" -j"$(nproc)" platform=unix CC="$TRIPLE-gcc-12 $INC" CXX="$TRIPLE-g++-12 $INC" LDFLAGS="$LIB"
        ;;
    *) echo "$CORE does not support target $TARGET yet" >&2; exit 2 ;;
esac

LIBFILE=$BUILD_DIR/${CORE}_libretro.so
[ -f "$LIBFILE" ] || { echo "build did not produce $LIBFILE" >&2; exit 1; }
$STRIP --strip-unneeded "$LIBFILE"
package_core "$CORE" "$TARGET" "$LIBFILE"
