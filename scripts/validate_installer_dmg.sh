#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DMG_PATH="${ROOT_DIR}/Free.dmg"
MOUNT_DIR="$(mktemp -d /tmp/free-dmg-smoke-XXXX)"

cleanup() {
    hdiutil detach "${MOUNT_DIR}" >/dev/null 2>&1 || true
    rmdir "${MOUNT_DIR}" >/dev/null 2>&1 || true
}
trap cleanup EXIT

echo "Building DMG for installer smoke test..."
"${ROOT_DIR}/package.sh" >/dev/null

echo "Mounting DMG..."
hdiutil attach -readonly -nobrowse -mountpoint "${MOUNT_DIR}" "${DMG_PATH}" >/dev/null

for required_item in "Install Free.app" "Free.app" "Applications"; do
    if [[ ! -e "${MOUNT_DIR}/${required_item}" ]]; then
        echo "Missing expected DMG item: ${required_item}" >&2
        exit 1
    fi
done

echo "Installer DMG smoke test passed."
