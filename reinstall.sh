#!/bin/bash
# reinstall.sh — run this after every Xcode build to update /Applications/cpMan.app.
#
# The app uses no TCC permissions, so there is nothing to reset. macOS still
# verifies the code signature on launch, which is why the script re-signs
# ad-hoc after the copy.
#
# Usage:
#   ./reinstall.sh
#
# What it does:
#   1. Finds the latest Debug build in DerivedData
#   2. Copies it to /Applications (all users on this Mac)
#   3. Re-signs with ad-hoc signature so macOS will launch it
#   4. Clears the quarantine xattr
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

codesign --sign - --force --deep "$DEST/cpMan.app"
xattr -cr "$DEST/cpMan.app"
echo "✅ Signed ad-hoc and cleared quarantine"

open "$DEST/cpMan.app"
echo ""
echo "✅ cpMan launched — look for the clipboard icon in the menu bar."
