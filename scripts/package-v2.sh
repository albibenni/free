#!/bin/bash
set -euo pipefail

# Build, Developer-ID-sign, and notarize the v2 app + its embedded content-filter
# system extension, then install to /Applications. A notarized Developer-ID build
# is the way to actually *activate* the system extension on a machine with SIP on
# (dev-signed system extensions require SIP-off developer mode; notarized ones
# don't). App Store submission is a separate flow — this is for real local testing.
#
# Requires release.env (CODESIGN_IDENTITY + NOTARY_PROFILE), same as v1 packaging.

cd "$(dirname "$0")/.."
[ -f release.env ] && source release.env
: "${NOTARY_PROFILE:?set NOTARY_PROFILE in release.env}"

rm -rf build/Free.xcarchive build/export build/Free.zip

echo "📦 Archiving (Release, Developer ID)…"
xcodebuild archive \
    -project Free.xcodeproj -scheme Free \
    -destination 'generic/platform=macOS' \
    -archivePath build/Free.xcarchive \
    -allowProvisioningUpdates

echo "📤 Exporting Developer ID app…"
xcodebuild -exportArchive \
    -archivePath build/Free.xcarchive \
    -exportPath build/export \
    -exportOptionsPlist Support/ExportOptions-DeveloperID.plist \
    -allowProvisioningUpdates

APP="build/export/Free.app"

echo "🛂 Notarizing…"
ditto -c -k --keepParent "$APP" build/Free.zip
xcrun notarytool submit build/Free.zip --keychain-profile "$NOTARY_PROFILE" --wait
xcrun stapler staple "$APP"

echo "🚀 Installing notarized build to /Applications…"
pkill -x Free 2>/dev/null || true
sleep 1
rm -rf /Applications/Free.app
cp -R "$APP" /Applications/Free.app

echo "✅ Done. Launch /Applications/Free.app and start a focus session; approve the"
echo "   extension in System Settings → General → Login Items & Extensions."
