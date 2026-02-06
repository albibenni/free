#!/bin/bash
set -e # Exit on error

APP_NAME="Free"
BUILD_DIR=".build/debug"
APP_BUNDLE="$APP_NAME.app"

# Compile
echo "Compiling..."
mkdir -p .build/debug
# Target macOS 13.0 for MenuBarExtra
swiftc Sources/Free/*.swift -o "$BUILD_DIR/$APP_NAME" -target arm64-apple-macosx13.0

# Create App Bundle Structure
echo "Creating Bundle..."
rm -rf "$APP_BUNDLE" # Clean previous build
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

# Copy Executable
cp "$BUILD_DIR/$APP_NAME" "$APP_BUNDLE/Contents/MacOS/"

# Copy Info.plist
cp Resources/Info.plist "$APP_BUNDLE/Contents/Info.plist"

# Copy Icon
cp AppIcon.icns "$APP_BUNDLE/Contents/Resources/"

echo "Done! You can run the app with: open $APP_BUNDLE"
