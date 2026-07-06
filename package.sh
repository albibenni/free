#!/bin/bash
set -euo pipefail

APP_NAME="Free"
APP_BUNDLE="$APP_NAME.app"
DMG_NAME="$APP_NAME.dmg"
DIST_DIR="dist"

# Optional local release config (gitignored): export CODESIGN_IDENTITY and
# NOTARY_PROFILE there so every ./package.sh is signed + notarized.
if [[ -f release.env ]]; then
    # shellcheck disable=SC1091
    source release.env
fi

echo "🚀 Starting packaging process..."

# 1. Build in Release mode (with optimizations)
echo "📦 Building Release binary..."
mkdir -p .build/release
# Deployment target must match Package.swift and Info.plist (macOS 26.0)
swiftc $(find Sources/Free -name "*.swift") -O -whole-module-optimization -o ".build/release/$APP_NAME" -swift-version 6 -target arm64-apple-macosx26.0

# 2. Create the .app bundle structure
echo "🏗️  Creating .app bundle..."
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

# Copy binary, plist, and icons
cp ".build/release/$APP_NAME" "$APP_BUNDLE/Contents/MacOS/"
cp Resources/Info.plist "$APP_BUNDLE/Contents/Info.plist"
cp AppIcon.icns "$APP_BUNDLE/Contents/Resources/"
printf 'APPL????' > "$APP_BUNDLE/Contents/PkgInfo"

# 3. Code sign
# Set CODESIGN_IDENTITY to a "Developer ID Application: ..." identity for
# distribution builds; unset, the bundle gets an ad-hoc signature so TCC
# grants (Accessibility/Automation/Calendar) survive rebuilds locally.
# Set NOTARY_PROFILE (a `notarytool store-credentials` profile) to notarize.
CODESIGN_IDENTITY="${CODESIGN_IDENTITY:--}"
echo "🔏 Signing with identity: $CODESIGN_IDENTITY"
codesign --force --deep --options runtime \
    --entitlements Resources/Free.entitlements \
    --sign "$CODESIGN_IDENTITY" "$APP_BUNDLE"
codesign --verify --strict "$APP_BUNDLE"

# 4. Create DMG
echo "💿 Creating Disk Image ($DMG_NAME)..."
rm -rf "$DIST_DIR"
mkdir -p "$DIST_DIR"
cp -R "$APP_BUNDLE" "$DIST_DIR/"
ln -s /Applications "$DIST_DIR/Applications"

# Use hdiutil to create the DMG
rm -f "$DMG_NAME"
hdiutil create -volname "$APP_NAME" -srcfolder "$DIST_DIR" -ov -format UDZO "$DMG_NAME"
codesign --force --sign "$CODESIGN_IDENTITY" "$DMG_NAME"

# 5. Notarize + staple (only when a real identity and notary profile are configured)
if [[ "$CODESIGN_IDENTITY" != "-" && -n "${NOTARY_PROFILE:-}" ]]; then
    echo "🛂 Notarizing..."
    xcrun notarytool submit "$DMG_NAME" --keychain-profile "$NOTARY_PROFILE" --wait
    xcrun stapler staple "$DMG_NAME"
fi

# Cleanup
rm -rf "$DIST_DIR"

echo "✅ Success! Your app is ready at: $DMG_NAME"
