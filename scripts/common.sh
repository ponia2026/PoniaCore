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
