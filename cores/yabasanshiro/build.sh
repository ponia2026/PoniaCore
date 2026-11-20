#!/bin/sh
# Build yabasanshiro for one target. Usage: build.sh <target>   (linux-arm64, linux-armhf)
# GLES builds, cross-compiled with gcc 12 against a Debian 12 sysroot.
HERE=$(cd "$(dirname "$0")" && pwd)
. "$HERE/../../scripts/common.sh"
. "$HERE/recipe.env"

TARGET=${1:?usage: build.sh <target>}
check_target "$TARGET"
setup_cross "$TARGET"

case "$TARGET" in
    linux-arm64) PLATFORM=$MAKE_PLATFORM_linux_arm64 ;;
    linux-armhf) PLATFORM=$MAKE_PLATFORM_linux_armhf
                 CROSS_CPU="-march=armv7-a -mfpu=neon -mfloat-abi=hard" ;;
    *) echo "$CORE does not support target $TARGET yet" >&2; exit 2 ;;
esac

SRC=$WORK_DIR/$CORE
fetch_source "$UPSTREAM_URL" "$UPSTREAM_REV" "$SRC"
BUILD_DIR=$SRC/$MAKE_DIR

clean_tree "$SRC"
# LDFLAGS goes in through the environment so the Makefile's own "LDFLAGS +=" still applies.
LDFLAGS="$CROSS_LIB -lGLESv2 -lEGL" make -C "$BUILD_DIR" -j"$(nproc)" platform="$PLATFORM" \
    CC="$CROSS_CC $CROSS_CPU $CROSS_INC" CXX="$CROSS_CXX $CROSS_CPU $CROSS_INC"

LIBFILE=$BUILD_DIR/${CORE}_libretro.so
[ -f "$LIBFILE" ] || { echo "build did not produce $LIBFILE" >&2; exit 1; }
$CROSS_STRIP --strip-unneeded "$LIBFILE"
package_core "$CORE" "$TARGET" "$LIBFILE"
