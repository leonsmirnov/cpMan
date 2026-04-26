#!/bin/bash
# Spotlight indexes every cpMan.app under Xcode DerivedData and local build/
# trees, so you see multiple "cpMan" next to the real ~/Applications install.
# This adds .metadata_never_index so macOS skips those folders (new builds too).
#
# Run once, or it runs from build-release-dmg-and-install.sh.
# Rebuild Spotlight cache if entries linger: System Settings → Siri & Spotlight,
# or: mdutil -E ~

set -euo pipefail
shopt -s nullglob

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

for d in "${HOME}/Library/Developer/Xcode/DerivedData"/cpMan-*; do
  if [ -d "$d" ]; then
    touch "$d/.metadata_never_index"
    echo "Spotlight: will ignore Xcode DerivedData → $d"
  fi
done

mkdir -p "${ROOT}/build"
touch "${ROOT}/build/.metadata_never_index"
echo "Spotlight: will ignore repo build dir → ${ROOT}/build"

if [ -d "${ROOT}/build/DerivedData" ]; then
  touch "${ROOT}/build/DerivedData/.metadata_never_index"
  echo "Spotlight: will ignore → ${ROOT}/build/DerivedData"
fi

if [ -d "${ROOT}/DerivedData" ]; then
  touch "${ROOT}/DerivedData/.metadata_never_index"
  echo "Spotlight: will ignore project DerivedData → ${ROOT}/DerivedData"
fi

echo "✅ Done. Duplicate cpMan entries should disappear after Spotlight reindexes (can take a few minutes)."
