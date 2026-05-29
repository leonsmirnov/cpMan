#!/bin/bash
# Launch cpMan with App Review demo content pre-loaded (15 fictional clips).
#
# Use this locally or paste the command into App Review Notes for Apple reviewers.
# Quit any running cpMan first so launch arguments are applied.
#
# Usage (from anywhere):
#   ./scripts/launch-cpman-demo-mode.sh
#
# Equivalent one-liner for App Store Connect review notes:
#   killall cpMan 2>/dev/null; open -b com.cpman.app --args -CPManDemoMode

set -euo pipefail

BUNDLE_ID="com.cpman.app"
DEMO_ARG="-CPManDemoMode"

echo "Quitting cpMan if running…"
killall cpMan 2>/dev/null || true
sleep 0.3

if [ -d "/Applications/cpMan.app" ]; then
  echo "Launching /Applications/cpMan.app with demo content…"
  open -a "/Applications/cpMan.app" --args "$DEMO_ARG"
elif open -Ra "$BUNDLE_ID" 2>/dev/null; then
  echo "Launching $BUNDLE_ID with demo content…"
  open -b "$BUNDLE_ID" --args "$DEMO_ARG"
else
  echo "❌ cpMan is not installed. Install from /Applications or the Mac App Store first."
  exit 1
fi

echo "✅ cpMan launched in demo mode."
echo "   Press ⌃⌥V to open the picker with sample clips."
