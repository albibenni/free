#!/bin/bash
set -euo pipefail

APP_NAME="Free"
APP_BUNDLE="$APP_NAME.app"
INSTALLER_BUNDLE="Install $APP_NAME.app"
DMG_NAME="$APP_NAME.dmg"
DIST_DIR="dist"
ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"

source_version() {
    /usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$ROOT_DIR/Resources/Info.plist"
}

source_build_number() {
    /usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$ROOT_DIR/Resources/Info.plist"
}

echo "🚀 Starting packaging process..."

# 1. Build in Release mode (with optimizations)
echo "📦 Building Release binary..."
mkdir -p .build/release
swiftc $(find Sources/Free -name "*.swift") -O -whole-module-optimization -o ".build/release/$APP_NAME" -target arm64-apple-macosx14.0

# 2. Create the .app bundle structure
echo "🏗️  Creating .app bundle..."
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

# Copy binary, plist, and icons
cp ".build/release/$APP_NAME" "$APP_BUNDLE/Contents/MacOS/"
cp Resources/Info.plist "$APP_BUNDLE/Contents/Info.plist"
cp AppIcon.icns "$APP_BUNDLE/Contents/Resources/"

# 3. Create standalone installer app for DMG-first install flow
echo "🧰 Building installer wrapper..."
rm -rf "$INSTALLER_BUNDLE"
"$ROOT_DIR/scripts/create_installer_app.sh" \
    "$APP_NAME" \
    "$ROOT_DIR" \
    "arm64-apple-macosx14.0" \
    "$(source_version)" \
    "$(source_build_number)"

# 4. Create DMG
echo "💿 Creating Disk Image ($DMG_NAME)..."
rm -rf "$DIST_DIR"
mkdir -p "$DIST_DIR"
cp -R "$APP_BUNDLE" "$DIST_DIR/"
cp -R "$INSTALLER_BUNDLE" "$DIST_DIR/"
ln -s /Applications "$DIST_DIR/Applications"

# Use hdiutil to create the DMG
rm -f "$DMG_NAME"
hdiutil create -volname "$APP_NAME" -srcfolder "$DIST_DIR" -ov -format UDZO "$DMG_NAME"

# Cleanup
rm -rf "$DIST_DIR"
rm -rf "$INSTALLER_BUNDLE"

echo "✅ Success! Your app is ready at: $DMG_NAME"
