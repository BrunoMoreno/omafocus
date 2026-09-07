#!/usr/bin/env sh
# Compile probe + behaviour tests for the omafocus plugin.
# Requires quickshell and the omarchy shell tree (OMARCHY_PATH, default /usr/share/omarchy).
set -e

OMARCHY_PATH="${OMARCHY_PATH:-/usr/share/omarchy}"
IMPPATH="${TMPDIR:-/tmp}/omafocus-imports"

DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
ROOT="$(CDPATH= cd -- "$DIR/.." && pwd)"

mkdir -p "$IMPPATH/qs"
ln -sfn "$OMARCHY_PATH/shell/Ui" "$IMPPATH/qs/Ui"
ln -sfn "$OMARCHY_PATH/shell/Commons" "$IMPPATH/qs/Commons"

export OMARCHY_PATH
export QML2_IMPORT_PATH="$IMPPATH"
export OMAFOCUS_DIR="$ROOT"

echo "== compile probe"
timeout 30 quickshell -p "$DIR/omafocus-probe.qml" || true

echo
echo "== behaviour tests"
timeout 30 quickshell -p "$DIR/omafocus-test.qml" || true