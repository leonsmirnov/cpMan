#!/bin/bash
# DerivedData / repo build trees add extra cpMan.app bundles. Spotlight may index
# them and Launch Services registers them — you see two “cpMan” (Applications +
# Debug folder).
#
# This script: .metadata_never_index on those trees, and unregisters every
# cpMan.app there (keeps files for Xcode). Refreshes /Applications/cpMan.app.
#
# Run once, or after changing Derived Data location. Normal Debug ⌘B uses
# scripts/finish-debug-install-to-applications.sh via scheme post-action.

set -euo pipefail
shopt -s nullglob

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LSREG="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"

lsreg_unregister_tree() {
  local base="$1"
  [ -d "$base" ] || return 0
  [ -x "$LSREG" ] || return 0
  while IFS= read -r -d '' p || [ -n "${p:-}" ]; do
    "$LSREG" -u -f "$p" 2>/dev/null || true
    echo "Launch Services: unregistered → $p"
  done < <(find "$base" -name "cpMan.app" -type d -print0 2>/dev/null)
}

for d in "${HOME}/Library/Developer/Xcode/DerivedData"/cpMan-*; do
  if [ -d "$d" ]; then
    touch "$d/.metadata_never_index"
    echo "Spotlight: will ignore Xcode DerivedData → $d"
    lsreg_unregister_tree "$d"
    if [ -x "$LSREG" ]; then
      "$LSREG" -u -f "${d}/Build/Products/Release/cpMan.app" 2>/dev/null || true
    fi
  fi
done

mkdir -p "${ROOT}/build"
touch "${ROOT}/build/.metadata_never_index"
echo "Spotlight: will ignore repo build dir → ${ROOT}/build"
lsreg_unregister_tree "${ROOT}/build"

if [ -d "${ROOT}/build/DerivedData" ]; then
  touch "${ROOT}/build/DerivedData/.metadata_never_index"
  echo "Spotlight: will ignore → ${ROOT}/build/DerivedData"
  lsreg_unregister_tree "${ROOT}/build/DerivedData"
  if [ -x "$LSREG" ]; then
    "$LSREG" -u -f "${ROOT}/build/DerivedData/Build/Products/Release/cpMan.app" 2>/dev/null || true
  fi
fi

if [ -d "${ROOT}/DerivedData" ]; then
  touch "${ROOT}/DerivedData/.metadata_never_index"
  echo "Spotlight: will ignore project DerivedData → ${ROOT}/DerivedData"
  lsreg_unregister_tree "${ROOT}/DerivedData"
fi

if [ -x "$LSREG" ] && [ -d "/Applications/cpMan.app" ]; then
  "$LSREG" -f "/Applications/cpMan.app" 2>/dev/null || true
  echo "Launch Services: refreshed /Applications/cpMan.app"
fi

echo "✅ Done. Extra cpMan entries should drop from Launchpad within a minute (or log out/in)."
