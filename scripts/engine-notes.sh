#!/usr/bin/env bash
#
# Prints the "The engine" section of a release's notes: the version of each
# project the bundled engine is built from, its licence, what changed since
# the release before, and where its source is. Their licences ask for it, and
# it shows which release brings an engine fix. CI adds it to each release;
# What's New leaves it out.
#
# Usage: scripts/engine-notes.sh [previous-tag]
#   previous-tag: the release before, to say which versions changed since

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REPO="${GITHUB_REPOSITORY:-orbtorrent/OrbTorrent}"
TAG="${GITHUB_REF_NAME:-main}"
PREVIOUS="${1:-}"

current="$(cat "$ROOT/engine/versions.env")"
before=""
if [[ -n "$PREVIOUS" ]]; then
  before="$(git -C "$ROOT" show "$PREVIOUS:engine/versions.env" 2>/dev/null)" ||
    { echo "error: can't read engine/versions.env at $PREVIOUS" >&2; exit 1; }
fi

version() { # version <versions.env text> <project>
  sed -n "s/^$2_VERSION=//p" <<<"$1"
}

# Project, its key in versions.env, its licence.
projects=(
  "qBittorrent (qbittorrent-nox)|QBITTORRENT|GPL-2.0-or-later"
  "libtorrent-rasterbar|LIBTORRENT|BSD-3-Clause"
  "Qt (qtbase, static)|QT|LGPL-3.0 / GPL"
  "OpenSSL (static)|OPENSSL|Apache-2.0"
  "Boost|BOOST|BSL-1.0"
)

rows="" changes=()
for project in "${projects[@]}"; do
  IFS="|" read -r name key licence <<<"$project"
  now="$(version "$current" "$key")"
  [[ -n "$now" ]] || { echo "error: no ${key}_VERSION in engine/versions.env" >&2; exit 1; }
  rows+="| ${name} | ${now} | ${licence} |"$'\n'
  if [[ -n "$before" ]]; then
    was="$(version "$before" "$key")"
    if [[ -n "$was" && "$was" != "$now" ]]; then
      changes+=("${name%% (*} ${was} → ${now}")
    fi
  fi
done

rows="${rows%$'\n'}"
source_url="https://github.com/$REPO/blob/$TAG"
cat <<EOF
## The engine

OrbTorrent runs qBittorrent's engine, built from source with:

| Project | Version | Licence |
|---|---|---|
${rows}
EOF
if [[ -n "$PREVIOUS" ]]; then
  echo
  if (( ${#changes[@]} )); then
    joined="$(printf '%s, ' "${changes[@]}")"
    echo "**Changed since $PREVIOUS:** ${joined%, }."
  else
    echo "Unchanged since $PREVIOUS."
  fi
fi
cat <<EOF

The source of each is attached below, as downloaded from the project and checked against the SHA-256 in [\`engine/versions.env\`]($source_url/engine/versions.env). It's built by [\`engine/build.sh\`]($source_url/engine/build.sh) with the patches in [\`engine/patches\`]($source_url/engine/patches). OrbTorrent's own source is this release's source code archive.
EOF
