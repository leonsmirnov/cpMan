#!/bin/bash
# Prepare for App Store app preview video recording.
# Launches demo mode and prints the timed storyboard.
#
# Usage: ./scripts/record-app-preview.sh

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STORY="${ROOT}/Documentation/AppStoreMedia/video-storyboard.md"

echo "═══════════════════════════════════════════════════════════════"
echo "  cpMan — App Preview recording prep"
echo "═══════════════════════════════════════════════════════════════"
echo ""

if [[ -d /Applications/cpMan.app ]]; then
  killall cpMan 2>/dev/null || true
  sleep 0.5
  open -n -a /Applications/cpMan.app --args -CPManDemoMode
  echo "Launched /Applications/cpMan.app in demo mode."
else
  echo "⚠️  cpMan not in /Applications. Run ./scripts/capture-app-store-raw.sh first"
  echo "   or install from the Mac App Store."
fi

echo ""
echo "Open Notes or TextEdit as your paste target."
echo ""
echo "QuickTime: File → New Screen Recording → record selected area."
echo "Target: 1920 x 1080 landscape, 15–30 seconds, H.264."
echo ""
echo "Storyboard:"
echo "───────────────────────────────────────────────────────────────"
if [[ -f "$STORY" ]]; then
  sed -n '/^## Timeline/,/^## Audio/p' "$STORY" | head -n -1
else
  echo "  See Documentation/AppStoreMedia/video-storyboard.md"
fi
echo "───────────────────────────────────────────────────────────────"
echo ""
echo "Export trimmed video to:"
echo "  Documentation/AppStoreMedia/output/cpMan-preview.mp4"
echo ""
echo "Optional (after brew install ffmpeg):"
echo "  ffmpeg -i ~/Desktop/recording.mov -t 25 -vf scale=1920:1080 -r 30 \\"
echo "    -c:v libx264 -pix_fmt yuv420p Documentation/AppStoreMedia/output/cpMan-preview.mp4"
