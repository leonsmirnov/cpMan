#!/bin/bash
# Capture raw UI screenshots for App Store marketing slides.
# Saves into Documentation/AppStoreMedia/raw/
#
# Usage: ./scripts/capture-app-store-raw.sh

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RAW="${ROOT}/Documentation/AppStoreMedia/raw"
mkdir -p "$RAW"

echo "═══════════════════════════════════════════════════════════════"
echo "  cpMan — Raw screenshot capture for App Store media"
echo "═══════════════════════════════════════════════════════════════"
echo ""
echo "This script builds cpMan, installs to /Applications, and launches"
echo "demo mode so you capture fictional sample clips only."
echo ""

# Build Debug and install
echo "Building cpMan (Debug)…"
cd "$ROOT"
xcodegen generate >/dev/null 2>&1 || true
xcodebuild -project cpMan.xcodeproj -scheme cpMan -configuration Debug build -quiet

APP="$(find ~/Library/Developer/Xcode/DerivedData -path "*/Build/Products/Debug/cpMan.app" -type d 2>/dev/null | head -1)"
if [[ -z "$APP" || ! -d "$APP" ]]; then
  echo "❌ Could not find Debug cpMan.app in DerivedData. Build in Xcode first."
  exit 1
fi

echo "Installing to /Applications/cpMan.app…"
killall cpMan 2>/dev/null || true
sleep 0.3
rm -rf /Applications/cpMan.app 2>/dev/null || true
ditto "$APP" /Applications/cpMan.app

echo "Launching demo mode…"
killall cpMan 2>/dev/null || true
sleep 0.5
open -n -a /Applications/cpMan.app --args -CPManDemoMode
sleep 2

capture() {
  local num="$1"
  local file="$2"
  local hint="$3"
  echo ""
  echo "───────────────────────────────────────────────────────────────"
  echo "  Capture $num → raw/$file"
  echo "  $hint"
  echo "───────────────────────────────────────────────────────────────"
  echo "  Press Enter when ready for interactive capture (crosshair)…"
  read -r
  local out="${RAW}/${file}"
  screencapture -i "$out"
  if [[ -f "$out" ]]; then
    echo "  ✅ Saved: $out"
  else
    echo "  ⚠️  Skipped or cancelled."
  fi
}

echo ""
echo "Tips:"
echo "  • Use Light Mode for consistency (System Settings → Appearance)."
echo "  • Capture the picker window or menu only — templates add the background."
echo "  • Press Esc to cancel any capture."
echo ""

capture "01" "01-picker.png"     "⌃⌥V → picker open, All tab, no search text"
capture "02" "02-search.png"     "Type 'roadmap' or 'git' in the search field"
capture "03" "03-images.png"       "Scroll to an image row (OCR demo screenshot)"
capture "04" "04-paste.png"        "Select a text row; optional: Notes visible behind picker"
capture "05" "05-menu.png"         "Click menu bar icon → show Private Mode submenu"
capture "06" "06-settings.png"       "Menu bar → Settings → General or History tab"

echo ""
echo "✅ Raw captures done. Next:"
echo "   ./scripts/export-app-store-slides.sh"
echo "   See Documentation/AppStoreMedia/README.md"
