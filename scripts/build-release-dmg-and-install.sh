#!/bin/bash
# Builds a Release cpMan.app, packages it into a DMG, and installs one copy
# under /Applications.
#
# Three signing modes (auto-detected from environment):
#
#   1. Developer ID + notarization (recommended for direct DMG distribution)
#      Requires:
#        CPMAN_DEVID_IDENTITY="Developer ID Application: Your Name (TEAMID)"
#        CPMAN_DEVELOPMENT_TEAM=TEAMID
#      Optional notarization:
#        CPMAN_NOTARY_PROFILE=<keychain profile created with `xcrun notarytool store-credentials`>
#      OR
#        CPMAN_NOTARY_APPLE_ID, CPMAN_NOTARY_APP_PASSWORD, CPMAN_DEVELOPMENT_TEAM
#
#   2. Ad-hoc (default, no Apple account needed — fine for local testing only)
#
#   3. App Store builds → use scripts/release-app-store-archive.sh instead.
#
# Usage (from repo root):
#   ./scripts/build-release-dmg-and-install.sh
#
# See Documentation/SigningAndDistribution.md for full instructions.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

DMG_NAME="cpMan-local-$(date +%Y-%m-%d-%H%M).dmg"
DMG_PATH="dist/${DMG_NAME}"

DEVID_IDENTITY="${CPMAN_DEVID_IDENTITY:-}"
DEV_TEAM="${CPMAN_DEVELOPMENT_TEAM:-}"
NOTARY_PROFILE="${CPMAN_NOTARY_PROFILE:-}"
NOTARY_APPLE_ID="${CPMAN_NOTARY_APPLE_ID:-}"
NOTARY_APP_PASSWORD="${CPMAN_NOTARY_APP_PASSWORD:-}"

if [ -n "$DEVID_IDENTITY" ]; then
  SIGN_MODE="developer-id"
  if [ -n "$NOTARY_PROFILE" ] || { [ -n "$NOTARY_APPLE_ID" ] && [ -n "$NOTARY_APP_PASSWORD" ] && [ -n "$DEV_TEAM" ]; }; then
    NOTARIZE=1
  else
    NOTARIZE=0
  fi
else
  SIGN_MODE="ad-hoc"
  NOTARIZE=0
fi

echo "Signing mode: $SIGN_MODE${NOTARIZE:+ (notarize=$NOTARIZE)}"

"$ROOT/scripts/clean-cpman-installs.sh"
"$ROOT/scripts/hide-dev-cpman-from-spotlight.sh"

command -v xcodegen >/dev/null   || { echo "Install xcodegen: brew install xcodegen"; exit 1; }
command -v create-dmg >/dev/null || { echo "Install create-dmg: brew install create-dmg"; exit 1; }

echo "Generating Xcode project…"
xcodegen generate
"$ROOT/scripts/apply-xcode-workspace-settings.sh"

echo "Cleaning Release build artifacts…"
rm -rf "${ROOT}/build/DerivedData"
mkdir -p "${ROOT}/build"
touch "${ROOT}/build/.metadata_never_index"
xcodebuild clean \
  -project cpMan.xcodeproj \
  -scheme cpMan \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  -derivedDataPath build/DerivedData \
  -quiet || true

echo "Resolving Swift packages…"
xcodebuild -project cpMan.xcodeproj -resolvePackageDependencies -scheme cpMan -quiet

echo "Building Release…"
set -o pipefail
if [ "$SIGN_MODE" = "developer-id" ]; then
  xcodebuild build \
    -project cpMan.xcodeproj \
    -scheme cpMan \
    -configuration Release \
    -destination 'generic/platform=macOS' \
    -derivedDataPath build/DerivedData \
    CODE_SIGN_STYLE=Manual \
    CODE_SIGN_IDENTITY="$DEVID_IDENTITY" \
    DEVELOPMENT_TEAM="$DEV_TEAM" \
    CODE_SIGNING_REQUIRED=YES \
    CODE_SIGNING_ALLOWED=YES \
    OTHER_CODE_SIGN_FLAGS="--timestamp --options runtime"
else
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
fi

APP="${ROOT}/build/DerivedData/Build/Products/Release/cpMan.app"
if [ ! -d "$APP" ]; then
  echo "❌ Expected app missing: $APP"; exit 1
fi

if [ "$SIGN_MODE" = "developer-id" ]; then
  echo "Verifying Developer ID signature…"
  codesign --verify --deep --strict --verbose=2 "$APP"
  spctl -a -t exec -vv "$APP" || echo "⚠️  spctl reports the app is not yet notarized (will fix below if NOTARIZE=1)."
fi

mkdir -p dist
rm -f "$DMG_PATH"
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

if [ "$SIGN_MODE" = "developer-id" ]; then
  echo "Signing DMG with Developer ID…"
  codesign --force --sign "$DEVID_IDENTITY" --timestamp "$DMG_PATH"
fi

if [ "$NOTARIZE" = "1" ]; then
  echo "Submitting DMG for notarization…"
  if [ -n "$NOTARY_PROFILE" ]; then
    xcrun notarytool submit "$DMG_PATH" --keychain-profile "$NOTARY_PROFILE" --wait
  else
    xcrun notarytool submit "$DMG_PATH" \
      --apple-id "$NOTARY_APPLE_ID" \
      --password "$NOTARY_APP_PASSWORD" \
      --team-id "$DEV_TEAM" \
      --wait
  fi
  echo "Stapling DMG…"
  xcrun stapler staple "$DMG_PATH"
fi

echo "Installing to /Applications (single system-wide copy)…"
DEST="/Applications"
mkdir -p "$DEST"

MOUNT=$(hdiutil attach "$DMG_PATH" -nobrowse | grep '/Volumes/' | tail -1 | awk '{print $3}')
if [ -z "$MOUNT" ] || [ ! -d "$MOUNT" ]; then
  echo "❌ Could not determine DMG mount point"; exit 1
fi

cleanup() { hdiutil detach "$MOUNT" -force 2>/dev/null || true; }
trap cleanup EXIT

rm -rf "${DEST}/cpMan.app"
cp -R "${MOUNT}/cpMan.app" "$DEST/"
xattr -cr "${DEST}/cpMan.app"

if [ -d "${HOME}/Applications/cpMan.app" ]; then
  echo "Removing duplicate ${HOME}/Applications/cpMan.app (canonical install is /Applications)…"
  rm -rf "${HOME}/Applications/cpMan.app"
fi

echo ""
echo "✅ DMG: $DMG_PATH (mode=$SIGN_MODE notarize=$NOTARIZE)"
echo "✅ Installed: ${DEST}/cpMan.app"
echo "   No system permissions required — launch from the menu bar icon or ⌃⌥V."

if [ -d "${ROOT}/build/DerivedData" ]; then
  echo "Removing ${ROOT}/build/DerivedData (avoids duplicate cpMan in Spotlight)…"
  rm -rf "${ROOT}/build/DerivedData"
fi
