#!/bin/bash
set -euo pipefail

# Build the v2 (App Store / Network Extension) app, install it to /Applications,
# and launch it there. Required because a content-filter system extension can only
# activate when its host app runs from /Applications — not from Xcode/DerivedData.
#
# Usage: ./scripts/run-v2.sh   (re-run after any code change)

cd "$(dirname "$0")/.."

echo "🔨 Building Free (signed)…"
xcodebuild build -project Free.xcodeproj -scheme Free \
    -destination 'platform=macOS' -allowProvisioningUpdates -quiet

APP=$(find "$HOME/Library/Developer/Xcode/DerivedData/Free-"*/Build/Products/Debug \
    -maxdepth 1 -name "Free.app" | head -1)
if [[ -z "${APP:-}" ]]; then echo "Build product not found"; exit 1; fi

echo "📦 Installing to /Applications…"
pkill -x Free 2>/dev/null || true
sleep 1
rm -rf /Applications/Free.app
cp -R "$APP" /Applications/Free.app

echo "🚀 Launching /Applications/Free.app…"
open /Applications/Free.app

cat <<'EOF'

✅ Running from /Applications. Now, in the app:
   1. Start a focus session.
   2. Approve the extension: System Settings → General →
      Login Items & Extensions → Network Extensions (allow "Free").
   3. If prompted "Free would like to filter network content" → Allow.
   4. Browse a blocked site in Brave to test.
EOF
