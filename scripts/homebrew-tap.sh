#!/usr/bin/env bash
#
# Writes OrbTorrent's Homebrew tap, github.com/orbtorrent/homebrew-tap, for a
# release: the cask, Casks/orbtorrent.rb, with the release's version and its
# disk image's SHA-256, and the tap's README. People install with
# `brew install orbtorrent/tap/orbtorrent`. CI writes and pushes it as each
# release is published (.github/workflows/homebrew.yml).
#
# Usage: scripts/homebrew-tap.sh <tag> <disk-image> <tap-dir>
#   scripts/homebrew-tap.sh v1.0-beta.2 OrbTorrent-1.0-universal.dmg homebrew-tap

set -euo pipefail

TAG="${1:?usage: homebrew-tap.sh <tag> <disk-image> <tap-dir>}"
DMG="${2:?the disk image of the release}"
TAP="${3:?the folder of the tap}"
REPO="${GITHUB_REPOSITORY:-orbtorrent/OrbTorrent}"

[[ "$TAG" =~ ^v[0-9][0-9A-Za-z.-]*$ ]] || { echo "error: $TAG isn't a release tag, such as v1.0-beta.2" >&2; exit 64; }
[[ -f "$DMG" ]] || { echo "error: no disk image at $DMG" >&2; exit 66; }
VERSION="${TAG#v}"
SHA256="$(shasum -a 256 "$DMG" | cut -d " " -f 1)"
# The disk image is named by the app's version, which stays 1.0 through the
# betas, so it's written out rather than made from the tag.
FILE="$(basename "$DMG")"

mkdir -p "$TAP/Casks"
cat >"$TAP/Casks/orbtorrent.rb" <<EOF
cask "orbtorrent" do
  version "$VERSION"
  sha256 "$SHA256"

  url "https://github.com/$REPO/releases/download/v#{version}/$FILE",
      verified: "github.com/$REPO/"
  name "OrbTorrent"
  desc "Torrent client for the menu bar, built on qBittorrent's engine"
  homepage "https://orbtorrent.com/"

  # The update feed OrbTorrent updates itself from. Its disk images are
  # downloaded from each release, whose tag is the version.
  livecheck do
    url "https://updates.orbtorrent.com/appcast.xml"
    strategy :sparkle do |items|
      items.filter_map { |item| item.url[%r{/download/v?([^/]+)/}i, 1] }
    end
  end

  auto_updates true
  depends_on macos: :tahoe

  app "OrbTorrent.app"

  uninstall quit: "com.orbtorrent.mac"

  zap trash: [
    "~/Library/Application Scripts/com.orbtorrent.mac.extension-host",
    "~/Library/Application Support/OrbTorrent",
    "~/Library/Caches/com.orbtorrent.mac",
    "~/Library/Containers/com.orbtorrent.mac.extension-host",
    "~/Library/HTTPStorages/com.orbtorrent.mac",
    "~/Library/Preferences/com.orbtorrent.mac.plist",
  ]
end
EOF

cat >"$TAP/README.md" <<EOF
# OrbTorrent for Homebrew

[OrbTorrent](https://orbtorrent.com) is a free, open-source torrent app for
the Mac, built on qBittorrent's engine. It lives in the menu bar.

\`\`\`sh
brew install orbtorrent/tap/orbtorrent
\`\`\`

It needs macOS 26 or later, on Apple silicon or Intel.

OrbTorrent keeps itself up to date, so \`brew upgrade\` leaves it alone unless
you add \`--greedy\`.

To uninstall it, \`brew uninstall orbtorrent\`. With \`--zap\`, your library
and settings go too. Your downloaded files stay where they are either way.

This cask is updated with each release of
[OrbTorrent](https://github.com/$REPO). Report problems
[there](https://github.com/$REPO/issues).
EOF

echo "Wrote OrbTorrent $VERSION's cask to $TAP/Casks/orbtorrent.rb"
