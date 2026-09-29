#!/usr/bin/env bash
#
# Packages OrbTorrent.app into a compressed, drag-to-install disk image.
#
# Usage: scripts/make-dmg.sh <path/to/OrbTorrent.app> [output-dir]
#
# Optional environment:
#   SIGN_IDENTITY   "Developer ID Application: …" to sign the disk image
#   NOTARY_PROFILE  notarytool keychain profile to notarize and staple it

set -euo pipefail

APP="${1:?usage: make-dmg.sh <OrbTorrent.app> [output-dir]}"
OUT="${2:-build}"
APP="$(cd "$(dirname "$APP")" && pwd)/$(basename "$APP")"

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist")"
ARCH_LABEL="$(lipo -archs "$APP/Contents/MacOS/qbittorrent-nox" | tr ' ' '\n' | sort | paste -sd- -)"
[[ "$ARCH_LABEL" == "arm64-x86_64" ]] && ARCH_LABEL="universal"
DMG="$OUT/OrbTorrent-$VERSION-$ARCH_LABEL.dmg"

STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT
cp -R "$APP" "$STAGE/OrbTorrent.app"
ln -s /Applications "$STAGE/Applications"

mkdir -p "$OUT"
rm -f "$DMG"
hdiutil create -quiet -volname "OrbTorrent" -srcfolder "$STAGE" -ov -format UDZO "$DMG"

if [[ -n "${SIGN_IDENTITY:-}" && "${SIGN_IDENTITY}" != "-" ]]; then
  codesign --sign "$SIGN_IDENTITY" --timestamp "$DMG"
fi
if [[ -n "${NOTARY_PROFILE:-}" ]]; then
  xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait
  xcrun stapler staple "$DMG"
fi

echo "Created $DMG ($(du -h "$DMG" | cut -f1))"
