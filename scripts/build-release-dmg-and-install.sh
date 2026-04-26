#!/bin/bash
# 1) Remove all previous cpMan.app installs
# 2) Build Release (ad-hoc signed, CI-style)
# 3) Create dist/cpMan-local-YYYY-MM-DD.dmg
# 4) Install exactly one copy to ~/Applications
#
# Usage (from repo root):
#   ./scripts/build-release-dmg-and-install.sh

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

DMG_NAME="cpMan-local-$(date +%Y-%m-%d).dmg"
DMG_PATH="dist/${DMG_NAME}"

"$ROOT/scripts/clean-cpman-installs.sh"
"$ROOT/scripts/hide-dev-cpman-from-spotlight.sh"

command -v xcodegen >/dev/null || { echo "Install xcodegen: brew install xcodegen"; exit 1; }
command -v create-dmg >/dev/null || { echo "Install create-dmg: brew install create-dmg"; exit 1; }

echo "Generating Xcode project…"
xcodegen generate
"$ROOT/scripts/apply-xcode-workspace-settings.sh"

echo "Resolving Swift packages…"
xcodebuild -project cpMan.xcodeproj -resolvePackageDependencies -scheme cpMan -quiet

echo "Building Release…"
set -o pipefail
xcodebuild build \
  -project cpMan.xcodeproj \
  -scheme cpMan \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  -derivedDataPath build/DerivedData \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=YES \
  CODE_SIGNING_ALLOWED=YES \
  AD_HOC_CODE_SIGNING_ALLOWED=YES

APP="${ROOT}/build/DerivedData/Build/Products/Release/cpMan.app"
if [ ! -d "$APP" ]; then
  echo "❌ Expected app missing: $APP"
  exit 1
fi

mkdir -p dist
rm -f "$DMG_PATH"
# Remove leftover read-write DMG stubs from failed runs
rm -f dist/rw.*."${DMG_NAME}" 2>/dev/null || true

echo "Creating DMG: $DMG_PATH"
create-dmg \
  --volname "cpMan" \
  --window-pos 200 120 \
  --window-size 600 400 \
  --icon-size 128 \
  --icon "cpMan.app" 150 185 \
  --hide-extension "cpMan.app" \
  --app-drop-link 450 185 \
  "$DMG_PATH" \
  "$APP"

echo "Installing to ~/Applications (single copy)…"
DEST="${HOME}/Applications"
mkdir -p "$DEST"

# Typical line: /dev/disk5s2	Apple_HFS	/Volumes/cpMan
MOUNT=$(hdiutil attach "$DMG_PATH" -nobrowse | grep '/Volumes/' | tail -1 | awk '{print $3}')
if [ -z "$MOUNT" ] || [ ! -d "$MOUNT" ]; then
  echo "❌ Could not determine DMG mount point"
  exit 1
fi

cleanup() {
  hdiutil detach "$MOUNT" -force 2>/dev/null || true
}
trap cleanup EXIT

rm -rf "${DEST}/cpMan.app"
cp -R "${MOUNT}/cpMan.app" "$DEST/"
xattr -cr "${DEST}/cpMan.app"

# Single install location: README recommends ~/Applications for a stable Accessibility
# grant. A second copy under /Applications (e.g. from dragging the DMG there) shows
# up as two “cpMan” apps in Finder / Spotlight — remove the system one.
if [ -d "/Applications/cpMan.app" ]; then
  echo "Removing duplicate /Applications/cpMan.app (keeping ~/Applications only)…"
  rm -rf "/Applications/cpMan.app"
fi

echo ""
echo "✅ DMG: $DMG_PATH"
echo "✅ Installed: ${DEST}/cpMan.app"
echo "   Launch from there (stable Accessibility path)."

# Command-line Release output lives here; without removal Spotlight keeps listing it
# as a second “app” next to ~/Applications.
if [ -d "${ROOT}/build/DerivedData" ]; then
  echo "Removing ${ROOT}/build/DerivedData (avoids duplicate cpMan in Spotlight)…"
  rm -rf "${ROOT}/build/DerivedData"
fi
