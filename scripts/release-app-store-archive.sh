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

echo "Archiving (Release, automatic signing)…"
# NOTE: We archive with AUTOMATIC signing and only pin the team. Passing a manual
# CODE_SIGN_IDENTITY / PROVISIONING_PROFILE_SPECIFIER globally on the command line
# forces those onto the KeyboardShortcuts Swift Package resource-bundle target,
# which fails with "does not support provisioning profiles". The App Store
# distribution identity + profile are applied later in -exportArchive via
# ExportOptions.plist (signingStyle: manual), which re-signs the app correctly.
xcodebuild archive \
  -project cpMan.xcodeproj \
  -scheme cpMan \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  -archivePath "$ARCHIVE" \
  -allowProvisioningUpdates \
  CODE_SIGN_STYLE=Automatic \
  DEVELOPMENT_TEAM="$CPMAN_DEVELOPMENT_TEAM"

echo "Writing export options…"
# Automatic signing for export lets Xcode select the matching App Store
# application + installer certificates and the distribution provisioning profile
# from your account. Manual pinning fails when the profile and the installer
# certificate ("3rd Party Mac Developer Installer" / "Apple Distribution") don't
# line up exactly — automatic resolves this the same way Xcode Organizer does.
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
    <string>automatic</string>
</dict>
</plist>
EOF

echo "Exporting .pkg for App Store Connect…"
xcodebuild -exportArchive \
  -allowProvisioningUpdates \
  -archivePath "$ARCHIVE" \
  -exportOptionsPlist "$EXPORT_PLIST" \
  -exportPath "$EXPORT_DIR"

echo ""
echo "✅ Archive: $ARCHIVE"
echo "✅ Package: ${EXPORT_DIR}/cpMan.pkg"
echo "   Next: Xcode → Organizer → Distribute App, or upload the .pkg with Transporter."
