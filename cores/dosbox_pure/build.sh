#!/bin/sh
# Build dosbox_pure for one target. Usage: build.sh <target>   (linux-armhf)
# Cross-compiled with gcc 12 against a Debian 12 sysroot; the upstream Makefile's generic Linux branch is used.
HERE=$(cd "$(dirname "$0")" && pwd)
. "$HERE/../../scripts/common.sh"
. "$HERE/recipe.env"

TARGET=${1:?usage: build.sh <target>}
check_target "$TARGET"
[ "$TARGET" = linux-armhf ] || { echo "$CORE does not support target $TARGET yet" >&2; exit 2; }
setup_cross "$TARGET"
# NEON baseline: the dynamic recompiler and the video scalers are too slow without it on 32-bit boards.
CPU="-march=armv7-a -mfpu=neon -mfloat-abi=hard"

SRC=$WORK_DIR/$CORE
fetch_source "$UPSTREAM_URL" "${UPSTREAM_REV:-origin/HEAD}" "$SRC"
BUILD_DIR=$SRC/$MAKE_DIR

clean_tree "$SRC"
# The link also goes through $(CXX), so the sysroot and library paths are part of the compiler string.
make -C "$BUILD_DIR" -j"$(nproc)" MAKE_CPUFLAGS="$CPU" STRIP="$CROSS_STRIP" \
    CXX="$CROSS_CXX $CPU $CROSS_INC $CROSS_LIB"

LIBFILE=$BUILD_DIR/${CORE}_libretro.so
[ -f "$LIBFILE" ] || { echo "build did not produce $LIBFILE" >&2; exit 1; }
$CROSS_STRIP --strip-unneeded "$LIBFILE"
package_core "$CORE" "$TARGET" "$LIBFILE"
