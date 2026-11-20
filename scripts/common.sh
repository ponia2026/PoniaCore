#!/bin/sh
# Shared helpers for core build scripts.
# Usage: . scripts/common.sh   (from a cores/<core>/build.sh)

set -eu

REPO_ROOT=$(cd "$(dirname "$0")/../.." && pwd)
WORK_DIR=${WORK_DIR:-$REPO_ROOT/work}
OUT_DIR=${OUT_DIR:-$REPO_ROOT/dist}

# Validate the target id passed as the first argument of build.sh.
check_target() {
    case "$1" in
        linux-x86_64|linux-arm64|linux-armhf) ;;
        *) echo "unsupported target: $1" >&2; exit 2 ;;
    esac
}

# Clone a pinned upstream revision: fetch_source <url> <commit> <dir>
fetch_source() {
    url=$1; rev=$2; dir=$3
    if [ ! -d "$dir/.git" ]; then
        git clone --recursive "$url" "$dir"
    fi
    git -C "$dir" fetch --tags origin
    git -C "$dir" checkout "$rev"
    git -C "$dir" submodule update --init --recursive
}

# Package a built core: package_core <core> <target> <path-to-.so>
package_core() {
    core=$1; target=$2; lib=$3
    commit=$(git -C "$REPO_ROOT" rev-parse --short=8 HEAD)
    date=$(date +%Y%m%d)
    mkdir -p "$OUT_DIR"
    name="PoniaCore_${core}-${date}.${commit}_${target}.zip"
    (cd "$(dirname "$lib")" && zip -j "$OUT_DIR/$name" "$(basename "$lib")")
    # Stable alias without date/commit: this is the name PoniaEmu downloads from the cores-latest release.
    cp "$OUT_DIR/$name" "$OUT_DIR/${core}_libretro_${target}.so.zip"
    echo "$OUT_DIR/$name"
}

# Set up a gcc 12 cross toolchain against a Debian 12 sysroot. Usage: setup_cross <target>
# Sets TRIPLE, SYSROOT, CROSS_CC, CROSS_CXX, CROSS_STRIP and the option strings CROSS_INC (headers),
# CROSS_LIB (library search paths) and CROSS_CPU (CPU flags). The sysroot's libm.so is a symlink with an
# absolute target that dangles on the host, so a shim directory with the real library is searched first;
# without it the host's newer libm is picked up and the core would need glibc 2.38.
setup_cross() {
    case "$1" in
        linux-arm64)
            TRIPLE=aarch64-linux-gnu
            SYSROOT=${SYSROOT:-/chroot/bookworm-arm64}
            CROSS_CPU="-march=armv8-a" ;;
        linux-armhf)
            TRIPLE=arm-linux-gnueabihf
            SYSROOT=${SYSROOT:-/chroot/bookworm-armhf}
            # ARMv7 with VFPv3-D16: the same baseline as the libretro buildbot's armv7-neon-hf cores.
            CROSS_CPU="-march=armv7-a -mfpu=vfpv3-d16 -mfloat-abi=hard" ;;
        *) echo "setup_cross: unsupported target $1" >&2; exit 2 ;;
    esac
    CROSS_CC=$TRIPLE-gcc-12
    CROSS_CXX=$TRIPLE-g++-12
    CROSS_STRIP=$TRIPLE-strip
    CROSS_INC="--sysroot=$SYSROOT -isystem $SYSROOT/usr/include/$TRIPLE -isystem $SYSROOT/usr/include"
    shim=$WORK_DIR/shims-$1
    mkdir -p "$shim"
    ln -sf "$SYSROOT/lib/$TRIPLE/libm.so.6" "$shim/libm.so"
    CROSS_LIB="--sysroot=$SYSROOT -L$shim -L$SYSROOT/usr/lib/$TRIPLE -L$SYSROOT/lib/$TRIPLE -L$SYSROOT/usr/lib/gcc/$TRIPLE/12 -Wl,-rpath-link,$SYSROOT/usr/lib/$TRIPLE:$SYSROOT/lib/$TRIPLE"
}

# Remove every build product from a source tree and its submodules, so objects of another target are never linked in.
clean_tree() {
    git -C "$1" clean -fdxq
    git -C "$1" submodule foreach --recursive 'git clean -fdxq' >/dev/null
}
