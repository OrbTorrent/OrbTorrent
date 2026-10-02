# Developing OrbTorrent

How OrbTorrent is built, how to build it yourself, and how releases go out.
To build an extension instead, see [the extension docs](https://orbtorrent.com/docs/extensions). To
send a change, see [CONTRIBUTING.md](../CONTRIBUTING.md).

## How it works

```
OrbTorrent.app
├── Contents/MacOS/OrbTorrent              SwiftUI app (menu bar, window, settings)
├── Contents/MacOS/qbittorrent-nox         qBittorrent's headless engine
├── Contents/MacOS/orb-extension-host      runs extensions, sandboxed
├── Contents/Frameworks/Sparkle.framework  updates
└── Contents/Resources/Extensions/         the official extensions
```

OrbTorrent starts `qbittorrent-nox` as a child process with its own profile in
`~/Library/Application Support/OrbTorrent/Engine` and talks to it through the
qBittorrent Web API:

- The API listens on `127.0.0.1` only, on a random free port.
- It's protected by a random password that OrbTorrent generates on first launch and
  stores readable only by you. It's saved in qBittorrent's PBKDF2 format.
- When OrbTorrent quits it asks the engine to shut down, so resume data is always saved.
  If the engine crashes, OrbTorrent restarts it.

The engine is statically linked: the binary depends only on macOS itself, so
OrbTorrent ships as one self-contained app.

Extensions run one at a time per hook in `orb-extension-host`, a small helper
with JavaScriptCore and the App Sandbox: it can't read files or reach the
network itself, and asks OrbTorrent for everything, which checks each request
against the extension's permissions. See
[Security model](https://orbtorrent.com/docs/extensions/security).

## Building

You need Xcode 26 or later, Node.js 22.13 or later (for the extensions), and
three command-line tools:

```sh
brew install cmake ninja xcodegen
```

Then:

```sh
make engine   # build qbittorrent-nox for this Mac (about 15 minutes the first time)
make sparkle  # download Sparkle, the updater (the other targets do it too)
make dev      # build OrbTorrent Dev, quit the running copy and open the new one
make run      # build OrbTorrent.app and open it
make test     # run the unit tests
make test-extensions  # the extension SDK's and the official extensions' tests
make dmg      # package build/OrbTorrent-<version>-<arch>.dmg
make release  # universal engine, app and DMG
```

`make project` generates `OrbTorrent.xcodeproj` from `project.yml` if you'd rather
work in Xcode. The build embeds `engine/dist/qbittorrent-nox`, the official
extensions, which `make extensions` builds, and
[Sparkle](https://sparkle-project.org), which `scripts/fetch-sparkle.sh`
downloads into `build/sparkle` and checks against its known checksum.

### OrbTorrent Dev

The Debug and Dev configurations build **OrbTorrent Dev**
(`com.orbtorrent.mac.dev`), so you can keep using OrbTorrent while you
work on it. It has its own library and engine in
`~/Library/Application Support/OrbTorrent Dev`, its own settings and Keychain
items, and an amber icon in the Dock and menu bar. It never opens magnet links
or `.torrent` files and doesn't start at login, leaving both to OrbTorrent.
Unit tests run inside it too. Point `orb dev` at it with `ORB_APP=dev`. Its
File menu has **Show Welcome** and **Show What's New**, to look at both
without a fresh install or an update; What's New uses sample notes until
Dev has read a feed. It
doesn't update itself, unless pointed at a test feed made by
`scripts/publish-update.sh --test`.

Builds are signed with a certificate from your Keychain when there is one
("Developer ID Application" or "Apple Development"), so macOS keeps the app's
permissions and Keychain access from one build to the next. Without one, as on
CI, they're signed ad hoc.

### The engine build

`engine/build.sh` builds every dependency from source, with nothing taken from
Homebrew or `/usr/local`:

| Component   | Version | Verified against |
|-------------|---------|------------------|
| qBittorrent | 5.2.3   | GPG signature (key `6E4A2D025B7CC9A2`) and qbittorrent.org checksum |
| libtorrent  | 1.2.20  | Pinned SHA-256 |
| Qt (qtbase + linguist tools) | 6.10.3 | download.qt.io SHA-256 |
| OpenSSL     | 3.6.4   | Upstream SHA-256 |
| Boost       | 1.86.0  | Upstream SHA-256 |

These versions mirror qBittorrent's own macOS release. Pins live in
`engine/versions.env`, and any fixes needed for newer toolchains live in
`engine/patches/<component>/`. Set `ARCHS="arm64 x86_64"` for a universal binary.

## The website and docs

`website/` is orbtorrent.com: an [Astro](https://astro.build) site whose
pages are all built ahead of time, with the docs at `/docs` built by
[Starlight](https://starlight.astro.build). A small Cloudflare Worker,
`website/src/worker.ts`, answers `/download/mac` with the newest disk image
from the update feed, and Cloudflare serves every other page as a file.

```sh
cd website
npm install
npm run dev      # the site and docs at http://localhost:4321, reloading as you edit
npm run build    # every page into dist/, checking the docs' links
```

- **The docs are Markdown** in `website/src/content/docs/docs/`, one file per
  page, and the sidebar is in `website/src/lib/docs-sidebar.mjs`. Every page
  needs a `title` and a `description`.
- **The build checks them:** every link between docs pages and to their
  headings must lead somewhere, and the API reference must have a heading for
  every export of `@orbtorrent/api` in `sdk/src/index.ts`. The extension SDK's
  changelog page shows `sdk/CHANGELOG.md` itself.
- **Each page is also Markdown** at its address plus `.md`, and `llms.txt`,
  `llms-full.txt` and `docs/extensions/llms-full.txt` are built from the
  docs, for language models.
- Change the SDK and its docs in the same pull request. CI builds the site
  whenever either changes.
- `npm run deploy` builds the site and publishes it, with the Worker, to
  orbtorrent.com.
- On a Mac, the Download buttons start the download without leaving the page.
  The Worker counts each one, without the address it came from, and
  `website/stats.sh` shows them by day, by the page they started on and by
  country. Pages are counted by Cloudflare Web Analytics.
- The footer's email sign-up, "Hear about big releases", keeps each address
  in a D1 database once it's confirmed from an email the Worker sends through
  Cloudflare Email Service. `npm test` in `website/` tests it,
  `npm run emails` builds the email, and `website/newsletter.sh` counts and
  exports the list. `website/AGENTS.md` has the details.

## Project layout

```
OrbTorrent/
  App/          App entry, delegate, commands, AppModel
  API/          qBittorrent Web API client and models
  Engine/       Engine process management and configuration
  Import/       Importing downloads and settings from Transmission and qBittorrent
  Store/        Library state, add flow, download order, VPN, disk space, notifications
  System/       Default app, login item, VPN detection and NAT-PMP port forwarding
  Parsing/      Bencode, .torrent metadata and magnet links
  Extensions/   Running extensions: registry, runner, checks, settings, dev socket
  Updates/      Automatic updates with Sparkle, and release notes for What's New
  Support/      Report a Problem
  Views/        SwiftUI views (main window, inspector, menu bar, settings, onboarding)
  Resources/    AppIcon.icon and OrbTorrent Dev's AppIconDev.icon (Icon Composer)
OrbTorrentTests/  The app's unit tests
ExtensionHost/  orb-extension-host, the sandboxed helper that runs extensions
extensions/     The official extensions (Fake Download Check, VirusTotal Scan)
sdk/            @orbtorrent/api: the extension API, the orb CLI and templates
  create-extension/  @orbtorrent/create-extension, for npm create @orbtorrent/extension@latest
skills/         The Agent Skill for building extensions
engine/         Engine build script, pinned versions and patches
updates/        updates.orbtorrent.com, the update feed (a Cloudflare Worker)
website/        orbtorrent.com and its docs, and the Worker in front of them
scripts/        DMG packaging, publishing updates, release notes, the Homebrew tap, the Agent Skill's AGENTS.md and permission checks
docs/           This guide, and the extension system's design
```

## Releasing

### Publishing an update

1. Raise `CURRENT_PROJECT_VERSION` in `project.yml`, and push a tag such as
   `v1.0-beta.2`. CI builds the disk image and makes a draft release, named
   "OrbTorrent 1.0 beta 2", with the engine's source attached. Its notes end
   with "The engine": the version and licence of each project in it, what
   changed since the release before, and links to the build script
   (`scripts/engine-notes.sh`).
2. On GitHub, write the release's notes in Markdown above that, with sections
   such as `## New`, `## Improved` and `## Fixed` and a bold first phrase for
   each item, and publish it. What's New in the app shows them the same way,
   without "The engine". When the engine changes for a fix, say so in the
   notes too. Publishing it also updates the cask in the Homebrew tap,
   `orbtorrent/homebrew-tap` (`.github/workflows/homebrew.yml`, writing
   `scripts/homebrew-tap.sh`).
3. Run `scripts/publish-update.sh v1.0-beta.2`. It signs the disk image and
   the feed with the key in your Keychain and puts the feed on
   `updates.orbtorrent.com`, where every copy finds it within a day.

For a fix to a version with a serious problem, add `--critical`: every older
version shows it at once and can't skip it. `--phased` reaches a seventh more
of the Macs each day, so a bad release can be stopped early, and
`scripts/publish-update.sh --withdraw v1.0-beta.3` takes a version off the
feed, and so off orbtorrent.com/download and the Homebrew tap, without
touching the Macs that have it.

Updates download in the background, and OrbTorrent restarts to install them
once it isn't in use (`AppModel.installUpdateWhenIdle`), coming back in the
menu bar with What's New waiting.

### Counting

`updates/` is the feed's Cloudflare Worker. Each check carries the anonymous
counts in `OrbTorrent/Updates/AnonymousCounts.swift`, which the Worker keeps
(`updates/src/counts.ts`, `npm test` there) in Analytics Engine, without the
address. `updates/stats.sh [days]` shows Macs each day, week and month, new
installs, versions, unexpected quits per version, how many keep using it by
the week installed, and macOS and chip. Cloudflare keeps 90 days. The privacy page lists every value; change
it with them (see `website/AGENTS.md`).

### Publishing the extension SDK

`@orbtorrent/api` (`sdk/`) and `@orbtorrent/create-extension`
(`sdk/create-extension/`) are on npm under the `orbtorrent` organisation.

1. Raise `version` in `sdk/package.json` and add it to `sdk/CHANGELOG.md`.
   The major and minor version are the extension API's: a patch version for
   changes to `orb` and fixes, a minor one for additions to the API, and a
   major one for anything that breaks an extension. For a new minor or major
   version, raise `ExtensionAPI.version` in `ExtensionManifest.swift` to match,
   so OrbTorrent runs what it builds.
2. Push a tag such as `sdk-v1.1.0`. CI checks both packages have that
   version, builds, tests and publishes them, through npm's trusted
   publishing, so no npm token is stored anywhere.

The two packages share a version and are released together: raise
`sdk/create-extension/package.json` to match. `npm create` always fetches the
newest `@orbtorrent/api` to make an extension from, so its template and
`AGENTS.md` are never older than what's on npm.

`node scripts/agent-eval.mjs` asks the coding agents on this Mac (Claude Code,
Codex and Cursor) to build three extensions from what the Develop tab's **Build
with AI** gives them, each in an empty folder with the SDK from npm, and checks
that they pass their tests, build, lint, run at the right moment and ask for no
more than they need. Run it after changing the SDK's docs or `AGENTS.md`.
