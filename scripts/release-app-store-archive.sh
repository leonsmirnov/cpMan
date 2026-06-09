#!/bin/bash
# Build a Mac App Store archive and export a signed .pkg for App Store Connect.
#
# Output:
#   build/AppStore/cpMan.xcarchive
#   build/AppStore/Export/cpMan.pkg
#
# Required env vars (see Documentation/SigningAndDistribution.md):
#   CPMAN_DEVELOPMENT_TEAM              e.g. "ABCDE12345"
#   CPMAN_APPSTORE_IDENTITY            e.g. "Apple Distribution: Your Name (ABCDE12345)"
#   CPMAN_APPSTORE_PROVISIONING_PROFILE  Mac App Store profile NAME or UUID for com.cpman.app
#
# Then open build/AppStore/cpMan.xcarchive in Xcode → Organizer → Distribute App,
# or upload the .pkg with Transporter / `xcrun altool`.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

: "${CPMAN_DEVELOPMENT_TEAM:?Set CPMAN_DEVELOPMENT_TEAM}"
: "${CPMAN_APPSTORE_IDENTITY:?Set CPMAN_APPSTORE_IDENTITY}"
: "${CPMAN_APPSTORE_PROVISIONING_PROFILE:?Set CPMAN_APPSTORE_PROVISIONING_PROFILE}"

command -v xcodegen >/dev/null || { echo "Install xcodegen: brew install xcodegen"; exit 1; }

ARCHIVE_DIR="${ROOT}/build/AppStore"
ARCHIVE="${ARCHIVE_DIR}/cpMan.xcarchive"
EXPORT_DIR="${ARCHIVE_DIR}/Export"
EXPORT_PLIST="${ARCHIVE_DIR}/ExportOptions.plist"

echo "Generating Xcode project…"
xcodegen generate

echo "Cleaning previous App Store artifacts…"
rm -rf "$ARCHIVE_DIR"
mkdir -p "$ARCHIVE_DIR"

echo "Resolving Swift packages…"
xcodebuild -project cpMan.xcodeproj -resolvePackageDependencies -scheme cpMan -quiet

echo "Archiving (Release, App Store signing)…"
xcodebuild archive \
  -project cpMan.xcodeproj \
  -scheme cpMan \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  -archivePath "$ARCHIVE" \
  CODE_SIGN_STYLE=Manual \
  CODE_SIGN_IDENTITY="$CPMAN_APPSTORE_IDENTITY" \
  DEVELOPMENT_TEAM="$CPMAN_DEVELOPMENT_TEAM" \
  PROVISIONING_PROFILE_SPECIFIER="$CPMAN_APPSTORE_PROVISIONING_PROFILE"

echo "Writing export options…"
cat > "$EXPORT_PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>app-store-connect</string>
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

echo "Exporting .pkg for App Store Connect…"
xcodebuild -exportArchive \
  -archivePath "$ARCHIVE" \
  -exportOptionsPlist "$EXPORT_PLIST" \
  -exportPath "$EXPORT_DIR"

echo ""
echo "✅ Archive: $ARCHIVE"
echo "✅ Package: ${EXPORT_DIR}/cpMan.pkg"
echo "   Next: Xcode → Organizer → Distribute App, or upload the .pkg with Transporter."
