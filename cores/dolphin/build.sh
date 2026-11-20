#!/bin/sh
# Build the dolphin core for one target. Usage: build.sh <target>
# Currently supports linux-arm64 (EGL + GLES, cross-compiled against a Debian 12 sysroot).
HERE=$(cd "$(dirname "$0")" && pwd)
. "$HERE/../../scripts/common.sh"
. "$HERE/recipe.env"

TARGET=${1:?usage: build.sh <target>}
check_target "$TARGET"

case "$TARGET" in
    linux-arm64)
        TRIPLE=aarch64-linux-gnu
        SYSROOT=${SYSROOT:-/chroot/bookworm-arm64}
        TOOLCHAIN=$REPO_ROOT/scripts/toolchains/aarch64-bookworm.cmake
        ;;
    *) echo "$CORE does not support target $TARGET yet" >&2; exit 2 ;;
esac

SRC=$WORK_DIR/$CORE
fetch_source "$UPSTREAM_URL" "$UPSTREAM_REV" "$SRC"

SHIM=$WORK_DIR/shims-$TARGET
mkdir -p "$SHIM"
ln -sf "$SYSROOT/lib/$TRIPLE/libm.so.6" "$SHIM/libm.so"

BUILD=$WORK_DIR/$CORE-build-$TARGET
# USE_SYSTEM_MBEDTLS=OFF: link the bundled mbedTLS, because the sonames of the system one differ between Debian releases.
# The sysroot glibc (2.36) has no strlcpy, but the feature check can pick it up from the newer host glibc,
# which would raise the core's glibc requirement to 2.38. Force it off.
cmake -S "$SRC" -B "$BUILD" -G Ninja \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_TOOLCHAIN_FILE="$TOOLCHAIN" -DPONIA_SYSROOT="$SYSROOT" -DPONIA_LIB_SHIM="$SHIM" \
    -DLIBRETRO=ON -DENABLE_X11=OFF -DENABLE_EGL=ON -DENABLE_VULKAN=OFF \
    -DHAVE_STRLCPY=0 -DENABLE_QT=OFF -DUSE_SYSTEM_MBEDTLS=OFF
cmake --build "$BUILD" --target dolphin_libretro -j"$(nproc)"

LIBFILE=$BUILD/${CORE}_libretro.so
[ -f "$LIBFILE" ] || { echo "build did not produce $LIBFILE" >&2; exit 1; }
$TRIPLE-strip --strip-unneeded "$LIBFILE"
package_core "$CORE" "$TARGET" "$LIBFILE"
