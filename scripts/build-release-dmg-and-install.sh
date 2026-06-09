#!/bin/bash
# 1) Remove all previous cpMan.app installs
# 2) Build Release (ad-hoc signed, CI-style)
# 3) Create dist/cpMan-local-YYYY-MM-DD-HHMM.dmg
# 4) Install exactly one copy to /Applications (all users on this Mac)
#
# Usage (from repo root):
#   ./scripts/build-release-dmg-and-install.sh
#
# Requires permission to write /Applications (admin users can usually `cp` there;
# if this fails, run from Terminal with sufficient privileges).

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

# Include time so repeated builds on the same day get distinct DMG names.
DMG_NAME="cpMan-local-$(date +%Y-%m-%d-%H%M).dmg"
DMG_PATH="dist/${DMG_NAME}"

"$ROOT/scripts/clean-cpman-installs.sh"
"$ROOT/scripts/hide-dev-cpman-from-spotlight.sh"

command -v xcodegen >/dev/null || { echo "Install xcodegen: brew install xcodegen"; exit 1; }
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

# Signing mode is auto-detected:
#   • CPMAN_DEVID_IDENTITY set → Developer ID signing (notarizable, public-ready)
#   • otherwise               → ad-hoc (local testing only, NOT for distribution)
SIGN_MODE="adhoc"
if [ -n "${CPMAN_DEVID_IDENTITY:-}" ]; then
  SIGN_MODE="devid"
fi

echo "Building Release (clean)… [signing mode: ${SIGN_MODE}]"
set -o pipefail
if [ "$SIGN_MODE" = "devid" ]; then
  # Developer ID + Hardened Runtime (already enabled in project.yml) + secure
  # timestamp → required for notarization. Embedded frameworks are signed too.
  xcodebuild build \
    -project cpMan.xcodeproj \
    -scheme cpMan \
    -configuration Release \
    -destination 'generic/platform=macOS' \
    -derivedDataPath build/DerivedData \
    CODE_SIGN_STYLE=Manual \
    CODE_SIGN_IDENTITY="$CPMAN_DEVID_IDENTITY" \
    DEVELOPMENT_TEAM="${CPMAN_DEVELOPMENT_TEAM:-}" \
    CODE_SIGNING_REQUIRED=YES \
    CODE_SIGNING_ALLOWED=YES \
    OTHER_CODE_SIGN_FLAGS="--timestamp"
else
  echo "⚠️  Building AD-HOC (local only). Set CPMAN_DEVID_IDENTITY for a notarizable, distributable build."
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
  echo "❌ Expected app missing: $APP"
  exit 1
fi

# ── Notarization helpers ───────────────────────────────────────────────────
# Returns 0 (and echoes the notarytool credential args) when creds are present.
notary_args() {
  if [ -n "${CPMAN_NOTARY_PROFILE:-}" ]; then
    echo "--keychain-profile ${CPMAN_NOTARY_PROFILE}"
    return 0
  fi
  if [ -n "${CPMAN_NOTARY_APPLE_ID:-}" ] && [ -n "${CPMAN_NOTARY_APP_PASSWORD:-}" ] && [ -n "${CPMAN_DEVELOPMENT_TEAM:-}" ]; then
    echo "--apple-id ${CPMAN_NOTARY_APPLE_ID} --password ${CPMAN_NOTARY_APP_PASSWORD} --team-id ${CPMAN_DEVELOPMENT_TEAM}"
    return 0
  fi
  return 1
}

NOTARIZE="no"
if [ "$SIGN_MODE" = "devid" ]; then
  if notary_args >/dev/null; then
    NOTARIZE="yes"
  else
    echo "⚠️  Developer ID build but no notary credentials (CPMAN_NOTARY_PROFILE or"
    echo "    CPMAN_NOTARY_APPLE_ID/CPMAN_NOTARY_APP_PASSWORD/CPMAN_DEVELOPMENT_TEAM)."
    echo "    The DMG will be signed but NOT notarized — Gatekeeper will still warn users."
  fi
fi

# Notarize + staple the .app before packaging so the stapled ticket travels in the DMG.
if [ "$NOTARIZE" = "yes" ]; then
  echo "Notarizing cpMan.app…"
  ZIP="${ROOT}/build/cpMan-notarize.zip"
  rm -f "$ZIP"
  /usr/bin/ditto -c -k --keepParent "$APP" "$ZIP"
  # shellcheck disable=SC2046
  xcrun notarytool submit "$ZIP" $(notary_args) --wait
  xcrun stapler staple "$APP"
  rm -f "$ZIP"
  echo "✅ App notarized and stapled"
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

# Notarize + staple the DMG itself so the downloaded disk image passes Gatekeeper.
if [ "$NOTARIZE" = "yes" ]; then
  echo "Notarizing DMG…"
  # shellcheck disable=SC2046
  xcrun notarytool submit "$DMG_PATH" $(notary_args) --wait
  xcrun stapler staple "$DMG_PATH"
  echo "✅ DMG notarized and stapled"
fi

echo "Installing to /Applications (single system-wide copy)…"
DEST="/Applications"
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

# Avoid two entries: legacy per-user install.
if [ -d "${HOME}/Applications/cpMan.app" ]; then
  echo "Removing duplicate ${HOME}/Applications/cpMan.app (canonical install is /Applications)…"
  rm -rf "${HOME}/Applications/cpMan.app"
fi

echo ""
echo "✅ DMG: $DMG_PATH"
echo "✅ Installed: ${DEST}/cpMan.app"
echo "   Grant Accessibility for this path in System Settings (⌘⇧G → /Applications if needed)."

# Command-line Release output lives here; without removal Spotlight keeps listing it
# as a second “app” next to /Applications.
if [ -d "${ROOT}/build/DerivedData" ]; then
  echo "Removing ${ROOT}/build/DerivedData (avoids duplicate cpMan in Spotlight)…"
  rm -rf "${ROOT}/build/DerivedData"
fi
