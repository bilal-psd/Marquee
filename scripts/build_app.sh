#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="Marquee"
BUNDLE_ID="com.marquee.app"
BUILD_DIR="$ROOT/.build"
BINARY_PATH="$BUILD_DIR/$APP_NAME"
APP_BUNDLE="$ROOT/$APP_NAME.app"
SDK="$(xcrun --show-sdk-path)"
TARGET="arm64-apple-macosx13.0"
SWIFTC="${SWIFTC:-}"

if [[ -z "$SWIFTC" && -x "/opt/homebrew/opt/swift/bin/swiftc" ]]; then
    SWIFTC="/opt/homebrew/opt/swift/bin/swiftc"
elif [[ -z "$SWIFTC" ]]; then
    SWIFTC="swiftc"
fi

echo "Building $APP_NAME with $SWIFTC..."
cd "$ROOT"
mkdir -p "$BUILD_DIR"

SOURCES=($(find Sources/Marquee -name '*.swift' | sort))

if swift build -c release 2>/dev/null; then
    cp "$BUILD_DIR/release/$APP_NAME" "$BINARY_PATH"
else
    echo "SwiftPM unavailable or mismatched; compiling with $SWIFTC..."
    "$SWIFTC" \
        -o "$BINARY_PATH" \
        -sdk "$SDK" \
        -target "$TARGET" \
        -O \
        -framework AppKit \
        -framework SwiftUI \
        -framework Combine \
        -framework ScriptingBridge \
        "${SOURCES[@]}"
fi

echo "Assembling app bundle..."
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

cp "$BINARY_PATH" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
chmod +x "$APP_BUNDLE/Contents/MacOS/$APP_NAME"

ICON_SRC="$ROOT/Resources/AppIcon.png"
if [[ -f "$ICON_SRC" ]]; then
    echo "Generating app icon..."
    ICONSET="$BUILD_DIR/AppIcon.iconset"
    rm -rf "$ICONSET"
    mkdir -p "$ICONSET"
    sips -z 16 16 "$ICON_SRC" --out "$ICONSET/icon_16x16.png" >/dev/null
    sips -z 32 32 "$ICON_SRC" --out "$ICONSET/icon_16x16@2x.png" >/dev/null
    sips -z 32 32 "$ICON_SRC" --out "$ICONSET/icon_32x32.png" >/dev/null
    sips -z 64 64 "$ICON_SRC" --out "$ICONSET/icon_32x32@2x.png" >/dev/null
    sips -z 128 128 "$ICON_SRC" --out "$ICONSET/icon_128x128.png" >/dev/null
    sips -z 256 256 "$ICON_SRC" --out "$ICONSET/icon_128x128@2x.png" >/dev/null
    sips -z 256 256 "$ICON_SRC" --out "$ICONSET/icon_256x256.png" >/dev/null
    sips -z 512 512 "$ICON_SRC" --out "$ICONSET/icon_256x256@2x.png" >/dev/null
    sips -z 512 512 "$ICON_SRC" --out "$ICONSET/icon_512x512.png" >/dev/null
    sips -z 1024 1024 "$ICON_SRC" --out "$ICONSET/icon_512x512@2x.png" >/dev/null
    iconutil -c icns "$ICONSET" -o "$APP_BUNDLE/Contents/Resources/AppIcon.icns"
fi

cat > "$APP_BUNDLE/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_ID</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSAppleEventsUsageDescription</key>
    <string>Marquee needs permission to control Apple Music and Spotify for playback.</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSHumanReadableCopyright</key>
    <string>Copyright © 2026 Mohammed Bilal</string>
</dict>
</plist>
EOF

echo "Signing app bundle..."
# Ad-hoc signature for local personal use. --deep is deprecated; this bundle has
# a single executable and no nested code, so sign it directly.
codesign --force --sign - "$APP_BUNDLE"

echo "Done: $APP_BUNDLE"
echo "Run with: open \"$APP_BUNDLE\""
