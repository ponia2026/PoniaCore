#!/bin/sh
# Build mupen64plus_next for one target. Usage: build.sh <target>
# Skeleton only: the real build steps are added when the first core is brought up.
. "$(dirname "$0")/../../scripts/common.sh"
. "$(dirname "$0")/recipe.env"

TARGET=${1:?usage: build.sh <target>}
check_target "$TARGET"

echo "TODO: build $CORE for $TARGET" >&2
exit 1
