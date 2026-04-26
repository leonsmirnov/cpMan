#!/bin/bash
# reinstall.sh — run this after every Xcode build to update /Applications/cpMan.app
# and re-grant Accessibility permission.
#
# Usage:
#   ./reinstall.sh
#
# What it does:
#   1. Finds the latest Debug build in DerivedData
#   2. Copies it to /Applications (all users on this Mac)
#   3. Re-signs with ad-hoc signature so macOS will launch it
#   4. Resets and re-grants Accessibility permission
#   5. Opens the app

set -e

APP=$(find ~/Library/Developer/Xcode/DerivedData/cpMan-*/Build/Products/Debug -name "cpMan.app" 2>/dev/null | head -1)

if [ -z "$APP" ]; then
  echo "❌ No Debug build found. Press ⌘B in Xcode first."
  exit 1
fi

echo "📦 Found build: $APP"

DEST="/Applications"
mkdir -p "$DEST"
rm -rf "$DEST/cpMan.app"
cp -R "$APP" "$DEST/"
rm -rf "$HOME/Applications/cpMan.app"
echo "✅ Copied to $DEST/cpMan.app"

# Sign and clear quarantine
codesign --sign - --force --deep "$DEST/cpMan.app"
xattr -cr "$DEST/cpMan.app"
echo "✅ Signed and cleared quarantine"

# Reset TCC and re-grant Accessibility
tccutil reset Accessibility com.cpman.app
echo "✅ Accessibility permission reset"

# Launch
open "$DEST/cpMan.app"
echo ""
echo "⚠️  Now go to: System Settings → Privacy & Security → Accessibility"
echo "   Find cpMan and toggle it ON"
echo "   You only need to do this once per reinstall."
