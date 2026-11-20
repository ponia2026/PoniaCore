#!/bin/sh
# Build the applewin core for one target. Usage: build.sh <target>   (linux-armhf)
# CMake, cross-compiled with gcc 12 against a Debian 12 sysroot. libyaml, zlib, minizip and spng come from the source tree.
HERE=$(cd "$(dirname "$0")" && pwd)
. "$HERE/../../scripts/common.sh"
. "$HERE/recipe.env"

TARGET=${1:?usage: build.sh <target>}
check_target "$TARGET"
[ "$TARGET" = linux-armhf ] || { echo "$CORE does not support target $TARGET yet" >&2; exit 2; }
setup_cross "$TARGET"
TOOLCHAIN=$REPO_ROOT/scripts/toolchains/armhf-bookworm.cmake

SRC=$WORK_DIR/$CORE
fetch_source "$UPSTREAM_URL" "$UPSTREAM_REV" "$SRC"

SHIM=$WORK_DIR/shims-$TARGET
BUILD=$WORK_DIR/$CORE-build-$TARGET
rm -rf "$BUILD"
cmake -S "$SRC" -B "$BUILD" -G Ninja \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_TOOLCHAIN_FILE="$TOOLCHAIN" -DPONIA_SYSROOT="$SYSROOT" -DPONIA_LIB_SHIM="$SHIM" \
    -DBUILD_LIBRETRO=ON
cmake --build "$BUILD" --target applewin_libretro -j"$(nproc)"

LIBFILE=$(find "$BUILD" -name "${CORE}_libretro.so" | head -1)
[ -n "$LIBFILE" ] && [ -f "$LIBFILE" ] || { echo "build did not produce ${CORE}_libretro.so" >&2; exit 1; }
$CROSS_STRIP --strip-unneeded "$LIBFILE"
package_core "$CORE" "$TARGET" "$LIBFILE"
