#!/bin/sh

set -eu

ROOT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"

mkdir -p "$DIST_DIR"
rm -rf "$DIST_DIR/Logi Fine Volume Down.app" "$DIST_DIR/Logi Fine Volume Up.app"

create_app() {
  app_name="$1"
  bundle_id="$2"
  script_name="$3"
  app_dir="$DIST_DIR/$app_name.app"

  mkdir -p "$app_dir/Contents/MacOS" "$app_dir/Contents/Resources"
  cp "$ROOT_DIR/src/$script_name" "$app_dir/Contents/Resources/$script_name"

  cat >"$app_dir/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleExecutable</key>
  <string>run</string>
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
  <key>LSBackgroundOnly</key>
  <true/>
</dict>
</plist>
EOF

  cat >"$app_dir/Contents/MacOS/run" <<EOF
#!/bin/sh
set -eu
APP_DIR=\$(CDPATH= cd -- "\$(dirname -- "\$0")/.." && pwd)
exec /usr/bin/osascript "\$APP_DIR/Resources/$script_name"
EOF

  chmod +x "$app_dir/Contents/MacOS/run"
}

create_app "Logi Fine Volume Down" "com.murat-taskaynatan.logi-fine-volume.down" "fine_volume_down.applescript"
create_app "Logi Fine Volume Up" "com.murat-taskaynatan.logi-fine-volume.up" "fine_volume_up.applescript"
