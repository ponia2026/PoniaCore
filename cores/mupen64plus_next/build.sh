#!/bin/sh
# Build mupen64plus_next for one target. Usage: build.sh <target>
# Currently supports linux-arm64 (GLES 3.0, cross-compiled against a Debian 12 sysroot).
# SYSROOT can be overridden; on CI it is created by scripts/setup-sysroot.sh.
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

# Link against the Debian 12 sysroot so the core does not need a newer glibc than the player.
INC="--sysroot=$SYSROOT -isystem $SYSROOT/usr/include/$TRIPLE -isystem $SYSROOT/usr/include"
LIB="--sysroot=$SYSROOT -L$SYSROOT/lib/$TRIPLE -L$SYSROOT/usr/lib/$TRIPLE -L$SYSROOT/usr/lib/gcc/$TRIPLE/12 -Wl,-rpath-link,$SYSROOT/usr/lib/$TRIPLE:$SYSROOT/lib/$TRIPLE"

make -C "$SRC" clean >/dev/null 2>&1 || true
# LDFLAGS goes in through the environment so the Makefile's own "LDFLAGS +=" (-shared, version script) still applies.
# The upstream generic GLES target does not link EGL, but GLideN64 calls eglGetProcAddress, so add it to GL_LIB.
LDFLAGS="$LIB" make -C "$SRC" -j"$(nproc)" platform="$PLATFORM" \
    CC="$TRIPLE-gcc $INC" CXX="$TRIPLE-g++ $INC" GL_LIB="-lGLESv2 -lEGL"

LIBFILE=$SRC/${CORE}_libretro.so
[ -f "$LIBFILE" ] || { echo "build did not produce $LIBFILE" >&2; exit 1; }
$TRIPLE-strip --strip-unneeded "$LIBFILE"
package_core "$CORE" "$TARGET" "$LIBFILE"
