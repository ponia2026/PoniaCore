#!/bin/sh
# Build the flycast core for one target. Usage: build.sh <target>   (linux-armhf)
# CMake, OpenGL ES, cross-compiled with gcc 12 against a Debian 12 sysroot.
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
    -DLIBRETRO=ON -DUSE_GLES=ON -DUSE_VULKAN=OFF -DUSE_HOST_LIBZIP=OFF -DUSE_OPENMP=OFF \
    -DUSE_BREAKPAD=OFF -DUSE_LUA=OFF -DUSE_DISCORD=OFF
cmake --build "$BUILD" -j"$(nproc)"

LIBFILE=$BUILD/${CORE}_libretro.so
[ -f "$LIBFILE" ] || { echo "build did not produce $LIBFILE" >&2; exit 1; }
$CROSS_STRIP --strip-unneeded "$LIBFILE"
package_core "$CORE" "$TARGET" "$LIBFILE"
