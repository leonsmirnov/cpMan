#!/bin/bash
# Launch cpMan with App Review demo content pre-loaded (15 fictional clips).
#
# IMPORTANT: cpMan must fully quit before relaunching with demo args. If cpMan is
# already running, `open --args` only reactivates it and does NOT pass -CPManDemoMode.
#
# Usage:
#   ./scripts/launch-cpman-demo-mode.sh
#
# One-liner for App Store Connect review notes:
#   killall cpMan 2>/dev/null; open -n -a "/Applications/cpMan.app" --args -CPManDemoMode

set -euo pipefail

BUNDLE_ID="com.cpman.app"
DEMO_ARG="-CPManDemoMode"
APP="/Applications/cpMan.app"

echo "Quitting cpMan if running…"
killall cpMan 2>/dev/null || true
sleep 0.5

# Confirm nothing is still running (menu-bar agents can linger briefly).
if pgrep -xq cpMan; then
  echo "❌ cpMan is still running. Quit it from the menu bar (Quit cpMan) and retry."
  exit 1
fi

if [ -d "$APP" ]; then
  echo "Launching $APP with demo content (-n forces a new process)…"
  open -n -a "$APP" --args "$DEMO_ARG"
elif open -Ra "$BUNDLE_ID" 2>/dev/null; then
  echo "Launching $BUNDLE_ID with demo content…"
  open -n -b "$BUNDLE_ID" --args "$DEMO_ARG"
else
  echo "❌ cpMan is not installed under $APP"
  echo "   Install from the Mac App Store or run ./scripts/build-release-dmg-and-install.sh"
  exit 1
fi

echo "✅ cpMan launched in demo mode."
echo "   Press ⌃⌥V — you should see ~15 sample clips (e.g. \"Team standup notes\")."
echo ""
echo "   If the list is still empty, run the binary directly:"
echo "   CPMAN_DEMO_MODE=1 $APP/Contents/MacOS/cpMan &"
