#!/bin/sh
# Build stella for one target. Usage: build.sh <target>   (linux-armhf)
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

# The compiler and linker options are put into the CC/CXX strings (the Makefile links through $(CXX) too).
# -include iomanip: some sources use std::setw/std::setfill without including <iomanip>, which gcc 12 no longer provides indirectly.
# GET_STATIC_ARG= keeps the Makefile from linking libgcc/libstdc++ statically: the cross compiler's static copies
# were built against a newer glibc than the sysroot has.
clean_tree "$SRC"
make -C "$BUILD_DIR" -j"$(nproc)" platform=armv7hardfloat GET_STATIC_ARG= \
    CC="$CROSS_CC $CROSS_CPU $CROSS_INC $CROSS_LIB" CXX="$CROSS_CXX $CROSS_CPU $CROSS_INC $CROSS_LIB -include iomanip" AR="$TRIPLE-ar"

LIBFILE=$BUILD_DIR/${CORE}_libretro.so
[ -f "$LIBFILE" ] || { echo "build did not produce $LIBFILE" >&2; exit 1; }
$CROSS_STRIP --strip-unneeded "$LIBFILE"
package_core "$CORE" "$TARGET" "$LIBFILE"
