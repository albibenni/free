#!/bin/bash
set -euo pipefail

APP_NAME="${1:-Free}"
OUTPUT_DIR="${2:-dist}"
TARGET="${3:-arm64-apple-macosx14.0}"
VERSION="${4:-1.0}"
BUILD_NUMBER="${5:-1}"
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
INSTALLER_SOURCE="${ROOT_DIR}/scripts/InstallerMain.swift"
INSTALLER_FLOW_SOURCE="${ROOT_DIR}/Sources/Free/Logic/InstallerFlow.swift"
ICON_PATH="${ROOT_DIR}/AppIcon.icns"

INSTALLER_NAME="Install ${APP_NAME}"
INSTALLER_EXECUTABLE="Install${APP_NAME}"
INSTALLER_BUNDLE="${OUTPUT_DIR}/${INSTALLER_NAME}.app"

mkdir -p "${INSTALLER_BUNDLE}/Contents/MacOS" "${INSTALLER_BUNDLE}/Contents/Resources"

swiftc \
  "${INSTALLER_FLOW_SOURCE}" \
  "${INSTALLER_SOURCE}" \
  -o "${INSTALLER_BUNDLE}/Contents/MacOS/${INSTALLER_EXECUTABLE}" \
  -parse-as-library \
  -target "${TARGET}"

cat > "${INSTALLER_BUNDLE}/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>${INSTALLER_NAME}</string>
    <key>CFBundleDisplayName</key>
    <string>${INSTALLER_NAME}</string>
    <key>CFBundleIdentifier</key>
    <string>com.benni.${APP_NAME}Installer</string>
    <key>CFBundleExecutable</key>
    <string>${INSTALLER_EXECUTABLE}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleVersion</key>
    <string>${BUILD_NUMBER}</string>
    <key>CFBundleShortVersionString</key>
    <string>${VERSION}</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon.icns</string>
    <key>InstallerTargetAppName</key>
    <string>${APP_NAME}</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <false/>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
PLIST

if [[ -f "${ICON_PATH}" ]]; then
  cp "${ICON_PATH}" "${INSTALLER_BUNDLE}/Contents/Resources/"
fi

echo "Created installer bundle: ${INSTALLER_BUNDLE}"
