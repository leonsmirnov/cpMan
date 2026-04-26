#!/bin/bash
# If you see 3× “cpMan” in Spotlight / Launchpad, they are usually:
#   1) /Applications/cpMan.app  (canonical install)
#   2) Xcode Debug under ~/Library/Developer/Xcode/DerivedData/cpMan-*
#   3) Release under <repo>/build/DerivedData/…
#
# This script: apply project-relative Derived Data, exclude build + DerivedData from
# Spotlight, and remove the global Xcode DerivedData folder for cpMan (safe; rebuilds).
#
# Usage: ./scripts/fix-cpman-triple-spotlight.sh

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

"$ROOT/scripts/apply-xcode-workspace-settings.sh"
"$ROOT/scripts/hide-dev-cpman-from-spotlight.sh"

echo ""
echo "Removing global Xcode DerivedData for cpMan (Debug will rebuild in ./DerivedData)…"
rm -rf "${HOME}/Library/Developer/Xcode/DerivedData"/cpMan-*

echo ""
echo "✅ Done."
echo "   • Re-open cpMan in Xcode and press ⌘B once."
echo "   • Spotlight may take a few minutes to drop old entries; optional:"
echo "       sudo mdutil -E /System/Volumes/Data"
