#!/bin/sh
# Build desmume2015 for one target. Usage: build.sh <target>   (linux-armhf)
HERE=$(cd "$(dirname "$0")" && pwd)
. "$HERE/../../scripts/common.sh"
. "$HERE/recipe.env"

TARGET=${1:?usage: build.sh <target>}
check_target "$TARGET"
[ "$TARGET" = linux-armhf ] || { echo "$CORE does not support target $TARGET yet" >&2; exit 2; }
setup_cross "$TARGET"

SRC=$WORK_DIR/$CORE
fetch_source "$UPSTREAM_URL" "$UPSTREAM_REV" "$SRC"
BUILD_DIR=$SRC/$MAKE_DIR

# "armv7-hardfloat" selects the 32-bit ARM dynarec of the core (ARM mode, hard float).
# The compiler and linker options are put into the CC/CXX strings (the Makefile links through $(CXX) too).
make -C "$BUILD_DIR" -f Makefile.libretro clean >/dev/null 2>&1 || true
make -C "$BUILD_DIR" -f Makefile.libretro -j"$(nproc)" platform=armv7-hardfloat \
    CC="$CROSS_CC $CROSS_CPU $CROSS_INC $CROSS_LIB" CXX="$CROSS_CXX $CROSS_CPU $CROSS_INC $CROSS_LIB" AR="$TRIPLE-ar"

LIBFILE=$BUILD_DIR/${CORE}_libretro.so
[ -f "$LIBFILE" ] || { echo "build did not produce $LIBFILE" >&2; exit 1; }
$CROSS_STRIP --strip-unneeded "$LIBFILE"
package_core "$CORE" "$TARGET" "$LIBFILE"
