#!/usr/bin/env bash
#
# Publishes an update: adds a release's disk image, signed, with its name and
# notes, to the update feed at updates.orbtorrent.com. Every installed
# OrbTorrent finds it within a day, and shows the notes in What's New once
# it's installed.
#
#   scripts/publish-update.sh v1.0-beta.2
#       From the published GitHub release with that tag: its disk image, its
#       name (such as "OrbTorrent 1.0 beta 2") and its notes, as written on
#       GitHub in Markdown.
#
#   scripts/publish-update.sh --critical v1.0-beta.3
#       The same, for a fix to a version with a serious problem: every older
#       version shows it straight away, and it can't be skipped. (Most install
#       updates by themselves anyway.)
#
#   scripts/publish-update.sh --phased v1.0-beta.3
#       The same, reaching a seventh more of the Macs each day, over a week,
#       so a bad release can be withdrawn before it reaches everyone. Check
#       for Updates still finds it at once.
#
#   scripts/publish-update.sh --withdraw v1.0-beta.3
#       Takes a version off the feed, so no more Macs update to it, and
#       orbtorrent.com/download and the Homebrew tap offer the version before.
#       Macs that have it keep it: publish a fix, --critical, for them.
#
#   scripts/publish-update.sh --dry-run v1.0-beta.2
#       Makes and checks the feed in build/update-feed without uploading it.
#
#   scripts/publish-update.sh --test <app.dmg> <notes.md> [name]
#       Adds a version to a test feed on this Mac, in build/update-test, for
#       trying an update in OrbTorrent Dev (rm -rf it to start again). Serve
#       it, and point OrbTorrent Dev at it, with:
#         python3 -m http.server 8123 --bind 127.0.0.1 --directory build/update-test
#         defaults write com.orbtorrent.mac.dev UpdateFeedURL http://127.0.0.1:8123/appcast.xml
#
# The feed and each update are signed with the key in the login Keychain
# (account "orbtorrent"), or SPARKLE_PRIVATE_KEY on CI. Uploading uses `cf`,
# signed in or with CLOUDFLARE_API_TOKEN.

set -euo pipefail

REPO=sanjevirau/OrbTorrent
FEED=https://updates.orbtorrent.com/appcast.xml
NAMESPACE=0cefcfed2afa4401925f69c2e74ced24
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
SPARKLE="$(scripts/fetch-sparkle.sh)/bin"

dry_run=false
test=false
withdraw=false
options=()
while [[ "${1:-}" == --* ]]; do
  case "$1" in
    --dry-run) dry_run=true ;;
    --test) test=true ;;
    --withdraw) withdraw=true ;;
    # Critical for every version before it.
    --critical) options+=(--critical-update-version "") ;;
    # Sparkle splits Macs into seven groups, a day apart.
    --phased) options+=(--phased-rollout-interval 86400) ;;
    *) echo "error: unknown option $1" >&2; exit 64 ;;
  esac
  shift
done
[[ $# -ge 1 ]] || { sed -n '3,40p' "$0" | sed 's/^# \{0,1\}//'; exit 64; }

KEY="$(mktemp -d)"
trap 'rm -rf "$KEY"' EXIT
chmod 700 "$KEY"
if [[ -n "${SPARKLE_PRIVATE_KEY:-}" ]]; then
  printf '%s' "$SPARKLE_PRIVATE_KEY" > "$KEY/key"
else
  "$SPARKLE/generate_keys" --account orbtorrent -x "$KEY/key" >/dev/null
fi

if $withdraw; then
  TAG="$1"
  WORK=build/update-feed
  rm -rf "$WORK" && mkdir -p "$WORK"
  curl -fsS -o "$WORK/appcast.xml" "$FEED"
  python3 - "$WORK/appcast.xml" "/releases/download/$TAG/" <<'PY'
import re, sys
path, download = sys.argv[1:3]
feed = open(path, encoding="utf-8").read()
items = [item for item in re.findall(r"[ \t]*<item>.*?</item>\n?", feed, re.S) if download in item]
if not items:
    sys.exit(f"error: the feed has no version from {download}")
for item in items:
    feed = feed.replace(item, "")
# The feed's old signature goes; it's signed again below.
feed = re.sub(r"\n?<!-- sparkle-signatures:.*?-->\n?", "\n", feed, flags=re.S)
open(path, "w", encoding="utf-8").write(feed)
PY
  NAME="$TAG"
elif $test; then
  WORK=build/update-test
  DMG="${1:?the disk image}"; NOTES="${2:?the notes, in Markdown}"; NAME="${3:-}"
  PREFIX=http://127.0.0.1:8123/
  LINK="https://github.com/$REPO/releases"
  # Like a release, only the new disk image is there beside the feed.
  mkdir -p "$WORK"
  find "$WORK" -mindepth 1 -maxdepth 1 ! -name appcast.xml -exec rm -rf {} +
  cp "$DMG" "$WORK/"
  ARCHIVE="$WORK/$(basename "$DMG")"
  cp "$NOTES" "${ARCHIVE%.dmg}.md"
else
  WORK=build/update-feed
  TAG="$1"
  if [[ "$(gh release view "$TAG" -R "$REPO" --json isDraft --jq .isDraft)" == true ]]; then
    echo "error: $TAG is still a draft. Write its notes and publish it on GitHub first." >&2
    exit 1
  fi
  NAME="$(gh release view "$TAG" -R "$REPO" --json name --jq .name)"
  LINK="$(gh release view "$TAG" -R "$REPO" --json url --jq .url)"
  PREFIX="https://github.com/$REPO/releases/download/$TAG/"
  rm -rf "$WORK" && mkdir -p "$WORK"
  gh release download "$TAG" -R "$REPO" -p '*.dmg' -D "$WORK"
  ARCHIVES=("$WORK"/*.dmg)
  [[ ${#ARCHIVES[@]} -eq 1 ]] || { echo "error: $TAG needs exactly one disk image." >&2; exit 1; }
  ARCHIVE="${ARCHIVES[0]}"
  gh release view "$TAG" -R "$REPO" --json body --jq .body > "${ARCHIVE%.dmg}.md"
  # Start from the feed as it is, so earlier versions stay in it.
  status="$(curl -sS -o "$WORK/appcast.xml" -w '%{http_code}' "$FEED")"
  case "$status" in
    200) ;;
    404) rm -f "$WORK/appcast.xml" ;;
    *) echo "error: couldn't read $FEED ($status)." >&2; exit 1 ;;
  esac
fi

if ! $withdraw; then
  # The notes as people read them in the app, without what GitHub adds for
  # itself: comments, first-time contributors and the "Full Changelog" link,
  # or the engine's versions (scripts/engine-notes.sh).
  python3 - "${ARCHIVE%.dmg}.md" <<'PY'
import re, sys
path = sys.argv[1]
notes = open(path, encoding="utf-8").read().replace("\r\n", "\n")
notes = re.sub(r"<!--.*?-->", "", notes, flags=re.S)
notes = re.sub(r"^#+ (?:New Contributors|The engine)\n(?:(?!#).*\n?)*", "", notes, flags=re.M)
notes = re.sub(r"^\s*\*\*Full Changelog\*\*.*$", "", notes, flags=re.M)
notes = re.sub(r" by @[\w-]+ in https://github\.com/\S+$", "", notes, flags=re.M)
open(path, "w", encoding="utf-8").write(re.sub(r"\n{3,}", "\n\n", notes).strip() + "\n")
PY

  "$SPARKLE/generate_appcast" --ed-key-file "$KEY/key" \
    --embed-release-notes --maximum-versions 0 \
    --download-url-prefix "$PREFIX" \
    ${LINK:+--link "$LINK"} \
    --full-release-notes-url "https://github.com/$REPO/releases" \
    ${options[@]+"${options[@]}"} \
    "$WORK"

  # Name the new version as its release does, such as "1.0 beta 2", for
  # Sparkle's window and What's New, then sign the feed again.
  python3 - "$WORK/appcast.xml" "$PREFIX$(basename "$ARCHIVE")" "${NAME#OrbTorrent }" <<'PY'
import re, sys
path, url, name = sys.argv[1:4]
feed = open(path, encoding="utf-8").read()
for item in re.findall(r"<item>.*?</item>", feed, re.S):
    if f'url="{url}"' in item and name:
        feed = feed.replace(item, re.sub(r"<title>.*?</title>", f"<title>{name}</title>", item, count=1))
open(path, "w", encoding="utf-8").write(feed)
PY
fi
"$SPARKLE/sign_update" --ed-key-file "$KEY/key" "$WORK/appcast.xml" >/dev/null
"$SPARKLE/sign_update" --verify --ed-key-file "$KEY/key" "$WORK/appcast.xml"

if $test || $dry_run; then
  echo "Made $WORK/appcast.xml"
  exit 0
fi

(cd updates && npx --no-install cf kv keys put appcast.xml --namespace-id "$NAMESPACE" \
  --file "$ROOT/$WORK/appcast.xml" >/dev/null)
if curl -fsS "$FEED" | cmp -s - "$WORK/appcast.xml"; then
  if $withdraw; then echo "Withdrew $TAG from $FEED"; else echo "Published ${NAME:-$TAG} to $FEED"; fi
else
  echo "Uploaded; $FEED may take a minute to show it."
fi

if $withdraw; then
  # The Homebrew tap goes back to the newest version left in the feed too.
  newest="$(python3 - "$WORK/appcast.xml" <<'PY'
import re, sys
feed = open(sys.argv[1], encoding="utf-8").read()
versions = []
for item in re.findall(r"<item>.*?</item>", feed, re.S):
    build = re.search(r"<sparkle:version>(\d+)</sparkle:version>", item)
    tag = re.search(r"/releases/download/([^/\"]+)/", item)
    if build and tag:
        versions.append((int(build.group(1)), tag.group(1)))
print(max(versions)[1] if versions else "")
PY
)"
  if [[ -n "$newest" ]]; then
    gh workflow run homebrew.yml -R "$REPO" -f tag="$newest"
    echo "The Homebrew tap goes back to $newest."
  fi
fi
