#!/usr/bin/env bash
#
# Packages OrbTorrent.app (or OrbTorrent Dev.app, to try updates) into a
# compressed, drag-to-install disk image, which is also what updates install
# from.
#
# Usage: scripts/make-dmg.sh <path/to/OrbTorrent.app> [output-dir]
#
# Optional environment:
#   SIGN_IDENTITY   "Developer ID Application: …" to sign the disk image
#   NOTARY_PROFILE  notarytool keychain profile to notarize and staple it
#   NOTARY_KEY      or an App Store Connect API key, the .p8 file, with
#                   NOTARY_KEY_ID and NOTARY_ISSUER, to do the same, as on CI

set -euo pipefail

APP="${1:?usage: make-dmg.sh <OrbTorrent.app> [output-dir]}"
OUT="${2:-build}"
APP="$(cd "$(dirname "$APP")" && pwd)/$(basename "$APP")"

NAME="$(basename "$APP" .app)"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist")"
ARCH_LABEL="$(lipo -archs "$APP/Contents/MacOS/qbittorrent-nox" | tr ' ' '\n' | sort | paste -sd- -)"
[[ "$ARCH_LABEL" == "arm64-x86_64" ]] && ARCH_LABEL="universal"
DMG="$OUT/${NAME// /-}-$VERSION-$ARCH_LABEL.dmg"

STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT
cp -R "$APP" "$STAGE/$NAME.app"
ln -s /Applications "$STAGE/Applications"

mkdir -p "$OUT"
rm -f "$DMG"
hdiutil create -quiet -volname "$NAME" -srcfolder "$STAGE" -ov -format UDZO "$DMG"

if [[ -n "${SIGN_IDENTITY:-}" && "${SIGN_IDENTITY}" != "-" ]]; then
  codesign --sign "$SIGN_IDENTITY" --timestamp "$DMG"
fi
NOTARY=()
if [[ -n "${NOTARY_PROFILE:-}" ]]; then
  NOTARY=(--keychain-profile "$NOTARY_PROFILE")
elif [[ -n "${NOTARY_KEY:-}" ]]; then
  NOTARY=(--key "$NOTARY_KEY" --key-id "${NOTARY_KEY_ID:?NOTARY_KEY needs NOTARY_KEY_ID}"
    --issuer "${NOTARY_ISSUER:?NOTARY_KEY needs NOTARY_ISSUER}")
fi
if [[ ${#NOTARY[@]} -gt 0 ]]; then
  xcrun notarytool submit "$DMG" "${NOTARY[@]}" --wait
  xcrun stapler staple "$DMG"
fi

echo "Created $DMG ($(du -h "$DMG" | cut -f1))"
