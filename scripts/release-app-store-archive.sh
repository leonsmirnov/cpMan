#!/bin/bash
# Builds an App Store-ready archive for cpMan and exports a .pkg you can upload
# via Xcode Organizer or Transporter.
#
# Usage:
#   ./scripts/release-app-store-archive.sh
#   ./scripts/release-app-store-archive.sh --export-only
#     (writes ExportOptions.plist + export only; requires an existing
#      build/AppStore/cpMan.xcarchive; does not delete the archive)
#
# Required environment:
#   CPMAN_DEVELOPMENT_TEAM=TEAMID                                  # 10-char Team ID
#   CPMAN_APPSTORE_IDENTITY="Apple Distribution: Your Name (TEAMID)"   # signing identity
#   CPMAN_APPSTORE_PROVISIONING_PROFILE=<profile name OR UUID>     # Mac App Store profile
#
# Optional — signs the exported .pkg:
#   CPMAN_APPSTORE_INSTALLER_IDENTITY="Mac Installer Distribution: …"
#   or "3rd Party Mac Developer Installer: …" (same role; Keychain often
#   still uses the legacy name). If unset, the script picks the first
#   installer identity from `security find-identity` (either name).
#
# The archive uses -configuration AppStore (see project.yml): only the cpMan
# app target uses Manual signing; SwiftPM must stay Automatic. Do not pass
# CODE_SIGN_STYLE=Manual / PROVISIONING_PROFILE_SPECIFIER on the xcodebuild
# command line or KeyboardShortcuts will fail ("does not support provisioning profiles").
#
# "No profile matching …": double-click the .provisionprofile to install it;
# ensure type is Mac App Store for com.cpman.app; use exact profile name or UUID.
#
# Output:
#   build/AppStore/cpMan.xcarchive
#   build/AppStore/Export/cpMan.pkg
#
# See Documentation/SigningAndDistribution.md for full instructions.

set -euo pipefail

EXPORT_ONLY=0
if [ "${1:-}" = "--export-only" ]; then
  EXPORT_ONLY=1
  shift
fi

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

: "${CPMAN_DEVELOPMENT_TEAM:?Set CPMAN_DEVELOPMENT_TEAM (10-char Team ID)}"
: "${CPMAN_APPSTORE_IDENTITY:?Set CPMAN_APPSTORE_IDENTITY (e.g. \"Apple Distribution: …\")}"
: "${CPMAN_APPSTORE_PROVISIONING_PROFILE:?Set CPMAN_APPSTORE_PROVISIONING_PROFILE (profile name or UUID)}"

ARCHIVE_DIR="$ROOT/build/AppStore"
ARCHIVE_PATH="$ARCHIVE_DIR/cpMan.xcarchive"
EXPORT_DIR="$ARCHIVE_DIR/Export"
EXPORT_OPTIONS="$ARCHIVE_DIR/ExportOptions.plist"

if [ "$EXPORT_ONLY" -eq 1 ]; then
  if [ ! -d "$ARCHIVE_PATH" ]; then
    echo "No archive at:" >&2
    echo "  $ARCHIVE_PATH" >&2
    echo "Run ./scripts/release-app-store-archive.sh without --export-only first." >&2
    exit 1
  fi
  echo "Export-only: using archive $ARCHIVE_PATH" >&2
  mkdir -p "$EXPORT_DIR"
else
  rm -rf "$ARCHIVE_DIR"
  mkdir -p "$EXPORT_DIR"

  command -v xcodegen >/dev/null || { echo "Install xcodegen: brew install xcodegen"; exit 1; }
  echo "Generating Xcode project…"
  xcodegen generate

  echo "Resolving Swift packages…"
  xcodebuild -project cpMan.xcodeproj -resolvePackageDependencies -scheme cpMan -quiet

  echo "Archiving App Store configuration (app target Manual; SPM stays Automatic)…"
  # -allowProvisioningUpdates: for Manual signing, xcodebuild can still fetch a
  # matching profile from the Developer portal if it isn't on disk yet (requires
  # the same Apple ID signed into Xcode → Settings → Accounts).
  xcodebuild archive \
    -project cpMan.xcodeproj \
    -scheme cpMan \
    -configuration AppStore \
    -destination 'generic/platform=macOS' \
    -archivePath "$ARCHIVE_PATH" \
    -allowProvisioningUpdates \
    CPMAN_DEVELOPMENT_TEAM="$CPMAN_DEVELOPMENT_TEAM" \
    CPMAN_APPSTORE_IDENTITY="$CPMAN_APPSTORE_IDENTITY" \
    CPMAN_APPSTORE_PROVISIONING_PROFILE="$CPMAN_APPSTORE_PROVISIONING_PROFILE" \
    CODE_SIGNING_REQUIRED=YES \
    CODE_SIGNING_ALLOWED=YES \
    OTHER_CODE_SIGN_FLAGS="--timestamp"
fi

# App Store .pkg signing: installer cert Common Name is often still
# "3rd Party Mac Developer Installer" in Keychain; ExportOptions must match
# that exact string — the selector "Mac Installer Distribution" does not match.
CPMAN_APPSTORE_INSTALLER_IDENTITY_RESOLVED="${CPMAN_APPSTORE_INSTALLER_IDENTITY:-}"
if [ -z "$CPMAN_APPSTORE_INSTALLER_IDENTITY_RESOLVED" ]; then
  # Pipeline may return non-empty stderr / grep miss; must not trip set -e before we check.
  set +e
  CPMAN_APPSTORE_INSTALLER_IDENTITY_RESOLVED="$(
    # Installer certs often do NOT appear under -p codesigning; use default listing.
    security find-identity -v 2>/dev/null \
      | grep -E '"(Mac Installer Distribution|3rd Party Mac Developer Installer):' \
      | head -1 \
      | awk -F'"' '{print $2}'
  )"
  set -e
fi
if [ -z "$CPMAN_APPSTORE_INSTALLER_IDENTITY_RESOLVED" ]; then
  echo "No installer signing identity found. Install Mac Installer Distribution" >&2
  echo "in Keychain, then set CPMAN_APPSTORE_INSTALLER_IDENTITY to the exact line from:" >&2
  echo "  security find-identity -v | grep -i installer" >&2
  exit 1
fi
echo "Installer signing identity: $CPMAN_APPSTORE_INSTALLER_IDENTITY_RESOLVED"

cat > "$EXPORT_OPTIONS" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>app-store-connect</string>
    <key>destination</key>
    <string>export</string>
    <key>teamID</key>
    <string>${CPMAN_DEVELOPMENT_TEAM}</string>
    <key>signingStyle</key>
    <string>manual</string>
    <key>signingCertificate</key>
    <string>${CPMAN_APPSTORE_IDENTITY}</string>
    <key>installerSigningCertificate</key>
    <string>${CPMAN_APPSTORE_INSTALLER_IDENTITY_RESOLVED}</string>
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
  -exportOptionsPlist "$EXPORT_OPTIONS" \
  -allowProvisioningUpdates

echo ""
echo "✅ Archive : $ARCHIVE_PATH"
echo "✅ Pkg    : $(find "$EXPORT_DIR" -name '*.pkg' | head -1)"
echo ""
echo "Next steps:"
echo "  • Upload via Xcode Organizer → Distribute App → App Store Connect, OR"
echo "  • xcrun altool / Transporter using the .pkg above."
