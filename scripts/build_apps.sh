#!/bin/sh

set -eu

ROOT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"

mkdir -p "$DIST_DIR"
rm -rf "$DIST_DIR/Logi Fine Volume Down.app" "$DIST_DIR/Logi Fine Volume Up.app"

osacompile -o "$DIST_DIR/Logi Fine Volume Down.app" "$ROOT_DIR/src/fine_volume_down.applescript"
osacompile -o "$DIST_DIR/Logi Fine Volume Up.app" "$ROOT_DIR/src/fine_volume_up.applescript"

/usr/libexec/PlistBuddy -c 'Add :LSUIElement bool true' "$DIST_DIR/Logi Fine Volume Down.app/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Add :LSUIElement bool true' "$DIST_DIR/Logi Fine Volume Up.app/Contents/Info.plist"
