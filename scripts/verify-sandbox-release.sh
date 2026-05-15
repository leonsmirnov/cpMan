#!/bin/bash
# Confirms a built cpMan.app is signed, hardened, sandboxed, and matches App Store
# requirements. Run on the .app produced by build-release-dmg-and-install.sh or
# release-app-store-archive.sh.
#
# Usage:
#   ./scripts/verify-sandbox-release.sh [path/to/cpMan.app]
#
# If no path is given, falls back to /Applications/cpMan.app.

set -uo pipefail

APP="${1:-/Applications/cpMan.app}"
if [ ! -d "$APP" ]; then
  echo "❌ App not found: $APP"; exit 1
fi

pass() { echo "✅ $1"; }
fail() { echo "❌ $1"; FAIL=1; }
FAIL=0

read_plist() {
  /usr/libexec/PlistBuddy -c "Print :$1" "$APP/Contents/Info.plist" 2>/dev/null || echo ""
}

echo "Checking: $APP"
echo "─────────────────────────────────────────────"

VER=$(read_plist CFBundleShortVersionString); VER=${VER:-?}
BUILD=$(read_plist CFBundleVersion); BUILD=${BUILD:-?}
echo "Version : $VER ($BUILD)"

ENT=$(codesign -d --entitlements :- "$APP" 2>/dev/null || true)

echo "$ENT" | grep -q "com.apple.security.app-sandbox" && \
  echo "$ENT" | grep -A1 "com.apple.security.app-sandbox" | grep -q "true" \
  && pass "App Sandbox enabled" || fail "App Sandbox NOT enabled"

if codesign -dv "$APP" 2>&1 | grep -E '^CodeDirectory' | grep -q "runtime"; then
  pass "Hardened Runtime enabled"
else
  fail "Hardened Runtime NOT enabled"
fi

IDENTITY=$(codesign -dv "$APP" 2>&1 | (grep -E '^Authority=' || true) | head -1 | sed 's/^Authority=//')
echo "Signed by: ${IDENTITY:-<ad-hoc>}"
case "$IDENTITY" in
  "Developer ID Application:"*) pass "Developer ID signing (suitable for direct DMG)" ;;
  "Apple Distribution:"*|"3rd Party Mac Developer Application:"*) pass "App Store distribution signing" ;;
  "")  echo "ℹ️  Ad-hoc signed (local testing only — will not pass App Store review or Gatekeeper for general users)";;
  *)   echo "ℹ️  Signing identity: $IDENTITY" ;;
esac

if codesign --verify --deep --strict --verbose=2 "$APP" >/dev/null 2>&1; then
  pass "codesign --verify (deep, strict) passes"
else
  fail "codesign verification failed"
fi

if [ -f "$APP/Contents/Resources/PrivacyInfo.xcprivacy" ]; then
  pass "Privacy manifest present"
else
  fail "Missing PrivacyInfo.xcprivacy"
fi

if [ -z "$(read_plist NSAccessibilityUsageDescription)" ]; then
  pass "NSAccessibilityUsageDescription absent (no TCC permission requested)"
else
  fail "NSAccessibilityUsageDescription unexpectedly set — the app must not request Accessibility"
fi

if [ "$(read_plist LSUIElement)" = "true" ]; then
  pass "Menu-bar-only (LSUIElement = true)"
else
  echo "ℹ️  LSUIElement not 1 — confirm intended Dock visibility."
fi

if spctl -a -t exec -vv "$APP" 2>&1 | grep -q "accepted"; then
  pass "Gatekeeper accepts the app (likely notarized or Developer ID-trusted)"
else
  echo "ℹ️  Gatekeeper does not accept yet — only matters for direct DMG distribution. App Store builds bypass this check."
fi

echo "─────────────────────────────────────────────"
if [ "$FAIL" = "1" ]; then
  echo "❌ Verification failed."
  exit 1
fi
echo "✅ All required checks passed."
