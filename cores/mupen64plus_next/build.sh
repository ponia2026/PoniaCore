#!/bin/sh
# Build mupen64plus_next for one target. Usage: build.sh <target>   (linux-arm64, linux-armhf)
# GLES3 builds, cross-compiled with gcc 12 against a Debian 12 sysroot.
HERE=$(cd "$(dirname "$0")" && pwd)
. "$HERE/../../scripts/common.sh"
. "$HERE/recipe.env"

TARGET=${1:?usage: build.sh <target>}
check_target "$TARGET"
setup_cross "$TARGET"

case "$TARGET" in
    linux-arm64) PLATFORM=$MAKE_PLATFORM_linux_arm64; EXTRA="" ;;
    linux-armhf)
        PLATFORM=$MAKE_PLATFORM_linux_armhf; EXTRA="FORCE_GLES3=1 ARCH=arm"
        # NEON baseline: the ARM32 dynarec and the GL plugin are too slow without it.
        CROSS_CPU="-march=armv7-a -mfpu=neon -mfloat-abi=hard" ;;
    *) echo "$CORE does not support target $TARGET yet" >&2; exit 2 ;;
esac

SRC=$WORK_DIR/$CORE
fetch_source "$UPSTREAM_URL" "$UPSTREAM_REV" "$SRC"

# LDFLAGS goes in through the environment so the Makefile's own "LDFLAGS +=" (-shared, version script) still applies.
# The upstream generic GLES targets do not link EGL, but GLideN64 calls eglGetProcAddress, so add it to GL_LIB.
clean_tree "$SRC"
LDFLAGS="$CROSS_LIB" make -C "$SRC" -j"$(nproc)" platform="$PLATFORM" $EXTRA \
    CC="$CROSS_CC $CROSS_CPU $CROSS_INC" CXX="$CROSS_CXX $CROSS_CPU $CROSS_INC" GL_LIB="-lGLESv2 -lEGL"

LIBFILE=$SRC/${CORE}_libretro.so
[ -f "$LIBFILE" ] || { echo "build did not produce $LIBFILE" >&2; exit 1; }
$CROSS_STRIP --strip-unneeded "$LIBFILE"
package_core "$CORE" "$TARGET" "$LIBFILE"
