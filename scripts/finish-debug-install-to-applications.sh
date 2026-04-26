#!/bin/bash
# Scheme Build Post-action (runs after embed / CopySwiftLibs).
# Copies the finished app to /Applications and removes the Debug (DerivedData)
# bundle from Launch Services so you only see one cpMan in Launchpad / Spotlight.
set -euo pipefail

if [ "${CONFIGURATION:-}" != "Debug" ]; then
  exit 0
fi

DEST="/Applications"
FULL_PRODUCT_NAME="${FULL_PRODUCT_NAME:-cpMan.app}"
APP="${BUILT_PRODUCTS_DIR}/${FULL_PRODUCT_NAME}"

if [ ! -d "$APP" ]; then
  echo "⚠️ finish-debug-install: missing $APP"
  exit 0
fi

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DD_ROOT="$(cd "${BUILT_PRODUCTS_DIR}/../../.." && pwd)"
LSREG="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"

rm -rf "${DEST}/${FULL_PRODUCT_NAME}"
cp -R "$APP" "$DEST/"
xattr -cr "${DEST}/${FULL_PRODUCT_NAME}"
rm -rf "${HOME}/Applications/${FULL_PRODUCT_NAME}"

# Never write files inside *.app — extra root files break the sealed bundle and CodeSign.
touch "${DD_ROOT}/.metadata_never_index"

lsreg_unregister() {
  [ -x "$LSREG" ] || return 0
  "$LSREG" -u -f "$1" 2>/dev/null || true
}

if [ -x "$LSREG" ]; then
  # Every on-disk bundle under this DerivedData (Debug + Index mirror, etc.).
  while IFS= read -r -d '' p || [ -n "${p:-}" ]; do
    lsreg_unregister "$p"
  done < <(find "$DD_ROOT" -name "cpMan.app" -type d -print0 2>/dev/null)

  # Stale DB rows from old Release builds (paths may no longer exist).
  lsreg_unregister "${DD_ROOT}/Build/Products/Release/${FULL_PRODUCT_NAME}"
  lsreg_unregister "${ROOT}/build/DerivedData/Build/Products/Release/${FULL_PRODUCT_NAME}"

  if [ -d "${ROOT}/build/DerivedData" ]; then
    while IFS= read -r -d '' p || [ -n "${p:-}" ]; do
      lsreg_unregister "$p"
    done < <(find "${ROOT}/build/DerivedData" -name "cpMan.app" -type d -print0 2>/dev/null)
  fi

  # Ensure the installed app is the canonical Launch Services entry.
  "$LSREG" -f "${DEST}/${FULL_PRODUCT_NAME}" 2>/dev/null || true
fi

echo "✅ finish-debug-install: ${FULL_PRODUCT_NAME} → ${DEST} (DerivedData unregistered from Launch Services)"
