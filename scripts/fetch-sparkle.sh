#!/usr/bin/env bash
#
# Downloads Sparkle, the updater built into OrbTorrent, into build/sparkle,
# checked against its known checksum: the framework the app embeds, and the
# command-line tools (generate_keys, sign_update, generate_appcast) that
# sign and publish updates. Prints the folder.
#
# Usage: "$(scripts/fetch-sparkle.sh)/bin/sign_update" …
#
# The update signing key lives in the login Keychain under the account
# "orbtorrent". The Keychain lets these exact tools read it without asking,
# so changing the version means allowing the new tools once.

set -euo pipefail

VERSION=2.10.0
SHA256=c2bf58aa8387266ac179357b1415d6f2635f044da8be41042af32425dae6da0c
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DIR="$ROOT/build/sparkle"

if [[ "$(cat "$DIR/VERSION" 2>/dev/null)" != "$VERSION" ]]; then
  ARCHIVE="$(mktemp -t sparkle).tar.xz"
  trap 'rm -f "$ARCHIVE"' EXIT
  curl -fsSL -o "$ARCHIVE" \
    "https://github.com/sparkle-project/Sparkle/releases/download/$VERSION/Sparkle-$VERSION.tar.xz"
  echo "$SHA256  $ARCHIVE" | shasum -a 256 -c - >/dev/null
  rm -rf "$DIR" && mkdir -p "$DIR"
  tar -xf "$ARCHIVE" -C "$DIR" bin Sparkle.framework LICENSE
  echo "$VERSION" > "$DIR/VERSION"
fi

echo "$DIR"
