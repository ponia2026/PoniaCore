#!/bin/sh
# Build mame2010 for one target. Usage: build.sh <target>
# Currently supports linux-armhf: 32-bit ARM, hard float, ARMv7 with VFPv3-D16 (the same baseline as the
# libretro buildbot's armv7-neon-hf cores), cross-compiled against a Debian 12 armhf sysroot with gcc 12.
HERE=$(cd "$(dirname "$0")" && pwd)
. "$HERE/../../scripts/common.sh"
. "$HERE/recipe.env"

TARGET=${1:?usage: build.sh <target>}
check_target "$TARGET"
[ "$TARGET" = linux-armhf ] || { echo "$CORE does not support target $TARGET yet" >&2; exit 2; }

TRIPLE=arm-linux-gnueabihf
SYSROOT=${SYSROOT:-/chroot/bookworm-armhf}

SRC=$WORK_DIR/$CORE
fetch_source "$UPSTREAM_URL" "$UPSTREAM_REV" "$SRC"
BUILD_DIR=$SRC/$MAKE_DIR

INC="--sysroot=$SYSROOT -isystem $SYSROOT/usr/include/$TRIPLE -isystem $SYSROOT/usr/include"
# The sysroot's libm.so is a symlink with an absolute target that dangles on the host; point a shim at the real library.
SHIM=$WORK_DIR/shims-$TARGET
mkdir -p "$SHIM"
ln -sf "$SYSROOT/lib/$TRIPLE/libm.so.6" "$SHIM/libm.so"
LIB="--sysroot=$SYSROOT -L$SHIM -L$SYSROOT/usr/lib/$TRIPLE -L$SYSROOT/lib/$TRIPLE -L$SYSROOT/usr/lib/gcc/$TRIPLE/12 -Wl,-rpath-link,$SYSROOT/usr/lib/$TRIPLE:$SYSROOT/lib/$TRIPLE"

# platform "armv7hardfloat" selects the Makefile's generic ARM branch (-marm, hard float, no x86 recompiler).
# The Makefile compiles with $(CXX) and assigns its flag variables with ":=", so the CPU flags and the sysroot options are
# put into the compiler command strings themselves (the final link also goes through $(CXX), so it needs the library
# search options too; otherwise it picks up the host's newer libm and the core would require glibc 2.38).
# FORCE_DRC_C_BACKEND=1 keeps the x86 recompiler backend out. KEEP_BUILD=1 reuses the object files of the last run.
CPU="-march=armv7-a -mfpu=vfpv3-d16"
if [ "${KEEP_BUILD:-0}" = 1 ]; then rm -f "$BUILD_DIR/${CORE}_libretro.so"; else make -C "$BUILD_DIR" clean >/dev/null 2>&1 || true; fi
make -C "$BUILD_DIR" -j"$(nproc)" platform=armv7hardfloat PTR64=0 ARM_ENABLED=1 FORCE_DRC_C_BACKEND=1 \
    CC="$TRIPLE-g++-12 $CPU $INC $LIB" CXX="$TRIPLE-g++-12 $CPU $INC $LIB" CC_AS="$TRIPLE-gcc-12 $CPU $INC" \
    LD="$TRIPLE-g++-12 $LIB" AR="$TRIPLE-ar"

LIBFILE=$BUILD_DIR/${CORE}_libretro.so
[ -f "$LIBFILE" ] || { echo "build did not produce $LIBFILE" >&2; exit 1; }
$TRIPLE-strip --strip-unneeded "$LIBFILE"
package_core "$CORE" "$TARGET" "$LIBFILE"
