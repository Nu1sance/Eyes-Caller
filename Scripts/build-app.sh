#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CONFIGURATION="${1:-release}"
APP_DIR="$ROOT_DIR/dist/EyesCaller.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

cd "$ROOT_DIR"
swift build -c "$CONFIGURATION"
BIN_DIR="$(swift build -c "$CONFIGURATION" --show-bin-path)"

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

/usr/bin/ditto "$BIN_DIR/EyesCaller" "$MACOS_DIR/EyesCaller"
/usr/bin/ditto "$ROOT_DIR/Support/Info.plist" "$CONTENTS_DIR/Info.plist"
/usr/bin/ditto "$ROOT_DIR/Sources/EyesCaller/Resources/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"
/usr/bin/ditto "$ROOT_DIR/Sources/EyesCaller/Resources/MenuBarIcon.png" "$RESOURCES_DIR/MenuBarIcon.png"
chmod +x "$MACOS_DIR/EyesCaller"

# Ad-hoc signing is sufficient for local development. Public distribution will
# still require a Developer ID certificate and Apple notarization.
/usr/bin/codesign --force --deep --sign - "$APP_DIR"

echo "Built local app: $APP_DIR"
echo "Run it with: open '$APP_DIR'"
