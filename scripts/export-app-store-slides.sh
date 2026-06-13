#!/bin/bash
# Export branded App Store screenshot PNGs (2880 x 1800) from HTML templates.
#
# Usage: ./scripts/export-app-store-slides.sh
#
# Prefers headless Chrome for one-click export. Falls back to opening slides
# in the browser for manual screenshot.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SLIDES="${ROOT}/Documentation/AppStoreMedia/templates/slides"
OUT="${ROOT}/Documentation/AppStoreMedia/output"
mkdir -p "$OUT"

CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
WIDTH=2880
HEIGHT=1800

export_one() {
  local html="$1"
  local base
  base="$(basename "$html" .html)"
  local outfile="${OUT}/${base}.png"
  local fileurl="file://${html}"

  if [[ -x "$CHROME" ]]; then
    "$CHROME" --headless=new --disable-gpu --hide-scrollbars \
      --window-size="${WIDTH},${HEIGHT}" \
      --screenshot="$outfile" \
      "$fileurl" 2>/dev/null
    if [[ -f "$outfile" ]]; then
      # Headless Chrome may capture at device scale; ensure dimensions
      sips -z "$HEIGHT" "$WIDTH" "$outfile" --out "$outfile" >/dev/null 2>&1 || true
      echo "  ✅ $outfile"
      return 0
    fi
  fi
  return 1
}

echo "Exporting App Store slides to: $OUT"
echo ""

if [[ -x "$CHROME" ]]; then
  echo "Using headless Chrome (${WIDTH}x${HEIGHT})…"
  ok=0
  for html in "$SLIDES"/*.html; do
    [[ -f "$html" ]] || continue
    if export_one "$html"; then
      ok=$((ok + 1))
    else
      echo "  ⚠️  Failed: $(basename "$html")"
    fi
  done
  if [[ "$ok" -gt 0 ]]; then
    echo ""
    echo "✅ Exported $ok slide(s)."
    echo "   Upload PNGs from: $OUT"
    echo "   To App Store Connect → version → Screenshots (Mac)."
    exit 0
  fi
fi

echo "Headless Chrome not available or export failed."
echo "Manual export:"
echo ""
for html in "$SLIDES"/*.html; do
  [[ -f "$html" ]] || continue
  echo "  1. open \"$html\""
  echo "  2. Screenshot the full page at 2880 x 1800 (or use Safari responsive mode)"
  echo "  3. Save as output/$(basename "$html" .html).png"
  echo ""
  open "$html" 2>/dev/null || true
  echo "  Press Enter for next slide…"
  read -r
done

echo "Done. Place files in: $OUT"
