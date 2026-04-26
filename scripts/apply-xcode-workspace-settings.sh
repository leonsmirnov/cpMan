#!/bin/bash
# After `xcodegen generate`, Xcode may drop user workspace settings. Re-apply
# project-relative Derived Data so Debug builds live under ./DerivedData (gitignored)
# instead of ~/Library/Developer/Xcode/DerivedData — then Spotlight ignores them via
# .metadata_never_index (see hide-dev-cpman-from-spotlight.sh).
#
# Usage: ./scripts/apply-xcode-workspace-settings.sh

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
USERN="$(id -un)"
SETTINGS="${ROOT}/cpMan.xcodeproj/project.xcworkspace/xcuserdata/${USERN}.xcuserdatad/WorkspaceSettings.xcsettings"

mkdir -p "$(dirname "$SETTINGS")"
if [ ! -f "$SETTINGS" ]; then
  plutil -create xml1 "$SETTINGS"
fi
plutil -replace BuildLocationStyle -integer 0 "$SETTINGS"
plutil -replace DerivedDataLocationStyle -integer 2 "$SETTINGS"
plutil -replace DerivedDataCustomLocation -string "DerivedData" "$SETTINGS"
echo "✅ Xcode will use project-relative Derived Data → ${ROOT}/DerivedData"
echo "   (Open the project in Xcode once so it migrates; next ⌘B writes there.)"
