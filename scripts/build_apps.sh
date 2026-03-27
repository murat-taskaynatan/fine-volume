#!/bin/sh

set -eu

ROOT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
RUNNER_BINARY="$ROOT_DIR/build/volume_runner"
HOTKEY_BINARY="$ROOT_DIR/build/volume_hotkeys"
HUD_BINARY="$ROOT_DIR/build/volume_hud"
CLI_BINARY="$ROOT_DIR/build/fine_volume_cli"
LAUNCH_AGENT_ID="com.murat-taskaynatan.fine-volume.hotkeys"
STEP_SIZE="2"
DOWN_STEP="-${STEP_SIZE}"
UP_STEP="${STEP_SIZE}"
DEFAULT_DOWN_KEY_CODE="38"
DEFAULT_UP_KEY_CODE="40"
DEFAULT_HOTKEY_MODIFIERS="5632"

mkdir -p "$DIST_DIR"
mkdir -p "$ROOT_DIR/build"
rm -rf \
  "$DIST_DIR/Fine Volume Down.app" \
  "$DIST_DIR/Fine Volume Up.app" \
  "$DIST_DIR/Fine Volume Hotkeys.app" \
  "$DIST_DIR/Logi Fine Volume Down.app" \
  "$DIST_DIR/Logi Fine Volume Up.app" \
  "$DIST_DIR/Logi Fine Volume Hotkeys.app" \
  "$DIST_DIR/fine-volume" \
  "$DIST_DIR/$LAUNCH_AGENT_ID.plist" \
  "$DIST_DIR/com.murat-taskaynatan.logi-fine-volume.hotkeys.plist"

/usr/bin/xcrun swiftc \
  "$ROOT_DIR/src/volume_common.swift" \
  "$ROOT_DIR/src/volume_runner.swift" \
  -framework Carbon \
  -o "$RUNNER_BINARY"
/usr/bin/xcrun swiftc \
  "$ROOT_DIR/src/volume_common.swift" \
  "$ROOT_DIR/src/volume_hotkeys.swift" \
  -framework Carbon \
  -o "$HOTKEY_BINARY"
/usr/bin/xcrun swiftc \
  "$ROOT_DIR/src/volume_common.swift" \
  "$ROOT_DIR/src/fine_volume_cli.swift" \
  -framework Carbon \
  -o "$CLI_BINARY"
/usr/bin/xcrun swiftc "$ROOT_DIR/src/volume_hud.swift" -o "$HUD_BINARY"

create_app() {
  app_name="$1"
  bundle_id="$2"
  step="$3"
  runner_name="$4"
  binary_path="$5"
  activation_mode="$6"
  app_dir="$DIST_DIR/$app_name.app"

  mkdir -p "$app_dir/Contents/MacOS"
  cp "$binary_path" "$app_dir/Contents/MacOS/$runner_name"
  cp "$HUD_BINARY" "$app_dir/Contents/MacOS/volume_hud"

  cat >"$app_dir/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleExecutable</key>
  <string>$runner_name</string>
  <key>CFBundleIdentifier</key>
  <string>$bundle_id</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>$app_name</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>1.0</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>$activation_mode</key>
  <true/>
EOF
  if [ "$step" != "none" ]; then
    cat >>"$app_dir/Contents/Info.plist" <<EOF
  <key>LFVStep</key>
  <integer>$step</integer>
EOF
  fi
  cat >>"$app_dir/Contents/Info.plist" <<EOF
</dict>
</plist>
EOF
  chmod +x "$app_dir/Contents/MacOS/$runner_name" "$app_dir/Contents/MacOS/volume_hud"
}

create_app \
  "Fine Volume Down" \
  "com.murat-taskaynatan.fine-volume.down" \
  "$DOWN_STEP" \
  "volume_runner_down" \
  "$RUNNER_BINARY" \
  "LSBackgroundOnly"
create_app \
  "Fine Volume Up" \
  "com.murat-taskaynatan.fine-volume.up" \
  "$UP_STEP" \
  "volume_runner_up" \
  "$RUNNER_BINARY" \
  "LSBackgroundOnly"
create_app \
  "Fine Volume Hotkeys" \
  "com.murat-taskaynatan.fine-volume.hotkeys" \
  "none" \
  "volume_hotkeys" \
  "$HOTKEY_BINARY" \
  "LSUIElement"

/usr/libexec/PlistBuddy -c "Add :LFVDownStep integer $DOWN_STEP" \
  "$DIST_DIR/Fine Volume Hotkeys.app/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Add :LFVUpStep integer $UP_STEP" \
  "$DIST_DIR/Fine Volume Hotkeys.app/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Add :LFVStepSizeDefault integer $STEP_SIZE" \
  "$DIST_DIR/Fine Volume Hotkeys.app/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Add :LFVDownKeyCodeDefault integer $DEFAULT_DOWN_KEY_CODE" \
  "$DIST_DIR/Fine Volume Hotkeys.app/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Add :LFVUpKeyCodeDefault integer $DEFAULT_UP_KEY_CODE" \
  "$DIST_DIR/Fine Volume Hotkeys.app/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Add :LFVHotkeyModifiersDefault integer $DEFAULT_HOTKEY_MODIFIERS" \
  "$DIST_DIR/Fine Volume Hotkeys.app/Contents/Info.plist"

cp "$CLI_BINARY" "$DIST_DIR/fine-volume"
chmod +x "$DIST_DIR/fine-volume"

cat >"$DIST_DIR/$LAUNCH_AGENT_ID.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>$LAUNCH_AGENT_ID</string>
  <key>ProgramArguments</key>
  <array>
    <string>$HOME/Applications/Fine Volume Hotkeys.app/Contents/MacOS/volume_hotkeys</string>
  </array>
  <key>RunAtLoad</key>
  <true/>
  <key>KeepAlive</key>
  <true/>
</dict>
</plist>
EOF
