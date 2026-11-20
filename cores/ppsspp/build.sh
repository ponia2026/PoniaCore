#!/bin/sh
# Build ppsspp for one target. Usage: build.sh <target>   (linux-arm64, linux-armhf)
# GLES builds, cross-compiled with gcc 12 against a Debian 12 sysroot.
HERE=$(cd "$(dirname "$0")" && pwd)
. "$HERE/../../scripts/common.sh"
. "$HERE/recipe.env"

TARGET=${1:?usage: build.sh <target>}
check_target "$TARGET"
setup_cross "$TARGET"

case "$TARGET" in
    linux-arm64)
        PLATFORM=$MAKE_PLATFORM_linux_arm64; EXTRA=""
        # The libretro file list has no libpng NEON sources on arm64, so turn its NEON hooks off.
        PNG_OPTS="-DPNG_ARM_NEON_OPT=0" ;;
    linux-armhf)
        PLATFORM=$MAKE_PLATFORM_linux_armhf
        CROSS_CPU="-march=armv7-a -mfpu=neon -mfloat-abi=hard"
        # The 32-bit ARM build compiles libpng's NEON assembly; assemble it with the cross compiler, not the host "as".
        EXTRA="TARGET_ARCH=arm"
        AS_CMD="$CROSS_CC $CROSS_CPU $CROSS_INC"
        PNG_OPTS="" ;;
    *) echo "$CORE does not support target $TARGET yet" >&2; exit 2 ;;
esac

SRC=$WORK_DIR/$CORE
fetch_source "$UPSTREAM_URL" "$UPSTREAM_REV" "$SRC"
BUILD_DIR=$SRC/$MAKE_DIR

clean_tree "$SRC"
# LDFLAGS goes in through the environment so the Makefile's own "LDFLAGS +=" still applies.
CFLAGS="$PNG_OPTS" LDFLAGS="$CROSS_LIB" make -C "$BUILD_DIR" -j"$(nproc)" platform="$PLATFORM" $EXTRA AS="${AS_CMD:-as}" \
    CC="$CROSS_CC $CROSS_CPU $CROSS_INC" CXX="$CROSS_CXX $CROSS_CPU $CROSS_INC -include stddef.h"

LIBFILE=$BUILD_DIR/${CORE}_libretro.so
[ -f "$LIBFILE" ] || { echo "build did not produce $LIBFILE" >&2; exit 1; }
$CROSS_STRIP --strip-unneeded "$LIBFILE"
package_core "$CORE" "$TARGET" "$LIBFILE"
