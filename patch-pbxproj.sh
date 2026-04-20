#!/bin/bash
# Run this once after `xcodegen generate` to patch the build script
# so it always runs (alwaysOutOfDate = 1 in pbxproj).

PBXPROJ="$(dirname "$0")/cpMan.xcodeproj/project.pbxproj"

if [ ! -f "$PBXPROJ" ]; then
  echo "❌ project.pbxproj not found — run xcodegen generate first"
  exit 1
fi

# Find the UUID of the Install script phase and add alwaysOutOfDate = 1
if grep -q "Install to ~/Applications" "$PBXPROJ"; then
  # Insert alwaysOutOfDate = 1 right before the shellScript line
  sed -i '' '/Install to ~\/Applications.*\*\/ = {/{
    n; n; n
    /alwaysOutOfDate/! s/^\(\s*\)name/\1alwaysOutOfDate = 1;\n\1name/
  }' "$PBXPROJ"
  echo "✅ Patched pbxproj — build script will now always run"
else
  echo "❌ Install script phase not found in pbxproj"
fi
