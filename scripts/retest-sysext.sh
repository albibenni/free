#!/bin/bash
set -euo pipefail

# Re-test whether the macOS Tahoe sysextd regression that blocks the v2 content
# filter is fixed on the current OS. See Docs/tahoe-sysext-bug.md.
#
# Usage: ./scripts/retest-sysext.sh
# Assumes the REAL notarized app is installed at /Applications/Free.app
# (build it with ./scripts/package-v2.sh — never run-v2.sh while SIP is on).

APP="/Applications/Free.app"
EXT_ID="com.benni.Free.ContentFilter"

echo "OS: $(sw_vers -productVersion) ($(sw_vers -buildVersion))"

if [ ! -d "$APP" ]; then
    echo "❌ $APP not installed. Run ./scripts/package-v2.sh first."
    exit 1
fi
if ! spctl -a -t exec "$APP" >/dev/null 2>&1; then
    echo "⚠️  $APP is not notarized/accepted by Gatekeeper — rebuild with"
    echo "    ./scripts/package-v2.sh (this test is only meaningful on the"
    echo "    notarized build)."
fi

echo "Already-activated system extensions:"
systemextensionsctl list 2>&1 | sed 's/^/  /'

echo "Launching $APP and watching sysextd for ~40s…"
pkill -x Free 2>/dev/null || true
sleep 1
START="$(date '+%Y-%m-%d %H:%M:%S')"
open "$APP"

# Wait for a verdict from either the app's own logging or sysextd.
for _ in $(seq 1 20); do
    if log show --start "$START" \
        --predicate 'subsystem == "com.benni.Free" OR process == "sysextd"' 2>/dev/null \
        | grep -Eiq "cannot allow apps outside|needs approval|activation finished|activated enabled|Extension not found"; then
        break
    fi
    sleep 2
done

LOGS="$(log show --start "$START" \
    --predicate 'subsystem == "com.benni.Free" OR process == "sysextd"' 2>/dev/null)"

echo "----------------------------------------"
if echo "$LOGS" | grep -qi "cannot allow apps outside"; then
    echo "❌ STILL BROKEN — Tahoe sysextd bug present on $(sw_vers -productVersion)."
    echo "   sysextd: 'no policy, cannot allow apps outside /Applications'"
    echo "$LOGS" | grep -Ei "realize|cannot allow|Extension not found" | tail -4 | sed 's/^/     /'
    exit 2
elif echo "$LOGS" | grep -Eqi "needs approval|activation finished|activated enabled"; then
    echo "✅ LOOKS FIXED — sysextd accepted the extension."
    echo "   Approve it: System Settings → General → Login Items & Extensions →"
    echo "   Network Extensions → allow 'Free', then re-run to confirm:"
    echo "     systemextensionsctl list"
    echo "$LOGS" | grep -Ei "approval|finished|activated" | tail -4 | sed 's/^/     /'
    exit 0
else
    echo "⚠️  Inconclusive — no clear verdict in the log window. Relevant lines:"
    echo "$LOGS" | grep -Ei "com.benni|sysextd|realize|activation" | tail -8 | sed 's/^/     /'
    echo "   Re-run, or check: log show --last 2m --predicate 'process == \"sysextd\"'"
    exit 3
fi
