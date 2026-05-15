#!/bin/bash
# Builds an App Store-ready archive for cpMan and exports a .pkg you can upload
# via Xcode Organizer or Transporter.
#
# Required environment:
#   CPMAN_DEVELOPMENT_TEAM=TEAMID                                  # 10-char Team ID
#   CPMAN_APPSTORE_IDENTITY="Apple Distribution: Your Name (TEAMID)"   # signing identity
#   CPMAN_APPSTORE_PROVISIONING_PROFILE=<profile name OR UUID>     # Mac App Store profile
#
# Output:
#   build/AppStore/cpMan.xcarchive
#   build/AppStore/Export/cpMan.pkg
#
# See Documentation/SigningAndDistribution.md for full instructions.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

: "${CPMAN_DEVELOPMENT_TEAM:?Set CPMAN_DEVELOPMENT_TEAM (10-char Team ID)}"
: "${CPMAN_APPSTORE_IDENTITY:?Set CPMAN_APPSTORE_IDENTITY (e.g. \"Apple Distribution: …\")}"
: "${CPMAN_APPSTORE_PROVISIONING_PROFILE:?Set CPMAN_APPSTORE_PROVISIONING_PROFILE (profile name or UUID)}"

ARCHIVE_DIR="$ROOT/build/AppStore"
ARCHIVE_PATH="$ARCHIVE_DIR/cpMan.xcarchive"
EXPORT_DIR="$ARCHIVE_DIR/Export"
EXPORT_OPTIONS="$ARCHIVE_DIR/ExportOptions.plist"

rm -rf "$ARCHIVE_DIR"
mkdir -p "$EXPORT_DIR"

command -v xcodegen >/dev/null || { echo "Install xcodegen: brew install xcodegen"; exit 1; }
echo "Generating Xcode project…"
xcodegen generate

echo "Resolving Swift packages…"
xcodebuild -project cpMan.xcodeproj -resolvePackageDependencies -scheme cpMan -quiet

echo "Archiving Release for App Store…"
xcodebuild archive \
  -project cpMan.xcodeproj \
  -scheme cpMan \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  -archivePath "$ARCHIVE_PATH" \
  CODE_SIGN_STYLE=Manual \
  CODE_SIGN_IDENTITY="$CPMAN_APPSTORE_IDENTITY" \
  DEVELOPMENT_TEAM="$CPMAN_DEVELOPMENT_TEAM" \
  PROVISIONING_PROFILE_SPECIFIER="$CPMAN_APPSTORE_PROVISIONING_PROFILE" \
  CODE_SIGNING_REQUIRED=YES \
  CODE_SIGNING_ALLOWED=YES \
  OTHER_CODE_SIGN_FLAGS="--timestamp"

cat > "$EXPORT_OPTIONS" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>app-store</string>
    <key>destination</key>
    <string>export</string>
    <key>teamID</key>
    <string>${CPMAN_DEVELOPMENT_TEAM}</string>
    <key>signingStyle</key>
    <string>manual</string>
    <key>signingCertificate</key>
    <string>${CPMAN_APPSTORE_IDENTITY}</string>
    <key>provisioningProfiles</key>
    <dict>
        <key>com.cpman.app</key>
        <string>${CPMAN_APPSTORE_PROVISIONING_PROFILE}</string>
    </dict>
</dict>
</plist>
EOF

echo "Exporting App Store .pkg…"
xcodebuild -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportPath "$EXPORT_DIR" \
  -exportOptionsPlist "$EXPORT_OPTIONS"

echo ""
echo "✅ Archive : $ARCHIVE_PATH"
echo "✅ Pkg    : $(find "$EXPORT_DIR" -name '*.pkg' | head -1)"
echo ""
echo "Next steps:"
echo "  • Upload via Xcode Organizer → Distribute App → App Store Connect, OR"
echo "  • xcrun altool / Transporter using the .pkg above."
