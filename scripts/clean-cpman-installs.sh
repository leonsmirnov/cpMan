#!/bin/bash
# Remove every installed cpMan.app we know about so you do not end up with
# multiple copies. Release + DMG install target is /Applications (all users);
# we also remove ~/Applications and other stray copies from older installs.
#
# Usage: ./scripts/clean-cpman-installs.sh

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

echo "Quitting cpMan if running…"
killall cpMan 2>/dev/null || true
sleep 0.3

unmount_dmg_volume() {
  if [ -d "/Volumes/cpMan" ]; then
    echo "Unmounting stale DMG volume /Volumes/cpMan…"
    hdiutil detach "/Volumes/cpMan" -force 2>/dev/null || true
  fi
}

remove_app_at() {
  local path="$1"
  if [ -d "$path" ]; then
    echo "Removing: $path"
    rm -rf "$path"
  fi
}

unmount_dmg_volume

# Canonical install: /Applications. Also clear legacy ~/Applications copy.
remove_app_at "${HOME}/Applications/cpMan.app"
remove_app_at "/Applications/cpMan.app"

# Common stray copies from opening the DMG or dragging elsewhere
remove_app_at "${HOME}/Desktop/cpMan.app"
remove_app_at "${HOME}/Downloads/cpMan.app"

# Also unregister Debug copies under Xcode DerivedData (Spotlight duplicates).
for d in "${HOME}/Library/Developer/Xcode/DerivedData"/cpMan-*; do
  if [ -d "${d}/Build/Products/Debug/cpMan.app" ]; then
    remove_app_at "${d}/Build/Products/Debug/cpMan.app"
  fi
  if [ -d "${d}/Build/Products/Release/cpMan.app" ]; then
    remove_app_at "${d}/Build/Products/Release/cpMan.app"
  fi
done

# Repo build output (not an install target, but removes Spotlight dupes)
remove_app_at "${ROOT}/build/DerivedData/Build/Products/Release/cpMan.app"
remove_app_at "${ROOT}/build/AppStore/cpMan.xcarchive/Products/Applications/cpMan.app"

echo "✅ cpMan install cleanup done (only standard paths; see script to add more)."
echo "   If Spotlight still shows extra cpMan icons, run: ./scripts/hide-dev-cpman-from-spotlight.sh"
