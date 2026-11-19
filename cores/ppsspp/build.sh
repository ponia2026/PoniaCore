#!/bin/sh
# Build ppsspp for one target. Usage: build.sh <target>
# Currently supports linux-arm64 (GLES 2/3, cross-compiled against a Debian 12 sysroot).
HERE=$(cd "$(dirname "$0")" && pwd)
. "$HERE/../../scripts/common.sh"
. "$HERE/recipe.env"

TARGET=${1:?usage: build.sh <target>}
check_target "$TARGET"

case "$TARGET" in
    linux-arm64)
        TRIPLE=aarch64-linux-gnu
        SYSROOT=${SYSROOT:-/chroot/bookworm-arm64}
        PLATFORM=$MAKE_PLATFORM_linux_arm64
        ;;
    *) echo "$CORE does not support target $TARGET yet" >&2; exit 2 ;;
esac

SRC=$WORK_DIR/$CORE
fetch_source "$UPSTREAM_URL" "$UPSTREAM_REV" "$SRC"
BUILD_DIR=$SRC/$MAKE_DIR

INC="--sysroot=$SYSROOT -isystem $SYSROOT/usr/include/$TRIPLE -isystem $SYSROOT/usr/include"
# The sysroot's libm.so is a symlink with an absolute target, which dangles on the host, so ld falls back to the
# static libm.a. Point a shim directory at the real shared library and search it first.
SHIM=$WORK_DIR/shims-$TARGET
mkdir -p "$SHIM"
ln -sf "$SYSROOT/lib/$TRIPLE/libm.so.6" "$SHIM/libm.so"
LIB="--sysroot=$SYSROOT -L$SHIM -L$SYSROOT/usr/lib/$TRIPLE -L$SYSROOT/lib/$TRIPLE -L$SYSROOT/usr/lib/gcc/$TRIPLE/12 -Wl,-rpath-link,$SYSROOT/usr/lib/$TRIPLE:$SYSROOT/lib/$TRIPLE"

make -C "$BUILD_DIR" clean >/dev/null 2>&1 || true
# LDFLAGS goes in through the environment so the Makefile's own "LDFLAGS +=" still applies.
# The bundled libpng has no NEON sources in the libretro file list, so turn its NEON hooks off.
CFLAGS="-DPNG_ARM_NEON_OPT=0" LDFLAGS="$LIB" make -C "$BUILD_DIR" -j"$(nproc)" platform="$PLATFORM" \
    CC="$TRIPLE-gcc $INC" CXX="$TRIPLE-g++ $INC"

LIBFILE=$BUILD_DIR/${CORE}_libretro.so
[ -f "$LIBFILE" ] || { echo "build did not produce $LIBFILE" >&2; exit 1; }
$TRIPLE-strip --strip-unneeded "$LIBFILE"
package_core "$CORE" "$TARGET" "$LIBFILE"
