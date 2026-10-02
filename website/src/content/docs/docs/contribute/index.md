---
title: Contribute to OrbTorrent
description: How to report problems, suggest features, build OrbTorrent from source, and send a change, with the project's layout and the rules for pull requests.
---

Bug reports, fixes and extensions are all welcome. OrbTorrent is open source, under the GNU GPL v3 or later, and lives on [GitHub](https://github.com/sanjevirau/OrbTorrent).

## Ways to help

- **Report a problem.** **Help › Report a Problem** in the app fills in what helps, or open an issue with the bug report form. [Report a problem](/docs/help/report-a-problem) explains.
- **Suggest a feature.** Check the [roadmap](https://github.com/sanjevirau/OrbTorrent/blob/main/ROADMAP.md) first, then open an issue with the feature request form. OrbTorrent aims to stay small and fit in on a Mac, so not every good idea will make it in. Many fit better as an extension.
- **Build an extension.** It doesn't need to be in the repository. Start with [Build extensions](/docs/extensions), then add yours to the [community list](/docs/extensions/sharing#the-community-list), or [propose it as an official extension](/docs/extensions/sharing#propose-an-official-extension).
- **Improve these docs.** Every page has **Edit page** at the bottom. The docs are Markdown, in `website/src/content/docs/docs/`.
- **Report a security problem** privately, by email, not in an issue. See [Security problems](/docs/help/report-a-problem#security-problems).

## Build it

You need **Xcode 26** or later, **Node.js 22.13** or later, and three tools from Homebrew:

```sh
brew install cmake ninja xcodegen
git clone https://github.com/sanjevirau/OrbTorrent.git
cd OrbTorrent
make engine   # build qBittorrent's engine (about 15 minutes the first time)
make dev      # build and open OrbTorrent Dev, which runs beside OrbTorrent
make test     # run the tests
```

| Command | Does |
|---|---|
| `make engine` | Builds `qbittorrent-nox` and everything it needs from source, each checked against a pinned checksum or signature. |
| `make dev` | Builds **OrbTorrent Dev**, quits the running copy and opens the new one. |
| `make run` | Builds OrbTorrent itself and opens it. |
| `make test` | Runs the app's tests. |
| `make test-extensions` | Runs the tests of the extension SDK, the official extensions and their scripts. |
| `make dmg` | Packages a disk image. |
| `make project` | Generates `OrbTorrent.xcodeproj` from `project.yml`, to work in Xcode. |

### OrbTorrent Dev

`make dev` builds **OrbTorrent Dev**, so you can keep using OrbTorrent while you work on it. It has its own library and engine in `~/Library/Application Support/OrbTorrent Dev`, its own settings and Keychain items, and an amber icon. It never opens magnet links or `.torrent` files, and doesn't start at login, leaving both to OrbTorrent. Point `orb` at it with `ORB_APP=dev`.

The repository's [development guide](https://github.com/sanjevirau/OrbTorrent/blob/main/docs/development.md) has the rest: the engine build, signing, the project layout, and how releases go out.

## Send a change

For anything bigger than a small fix, open an issue first, so we can agree on the approach before you spend time on it.

1. Work in **OrbTorrent Dev**, so your everyday library is safe.
2. Match the code around your change: its naming, structure and amount of comments. Text people see in the app is short, plain English.
3. Add or update tests for what you change, and run them with `make test` and `make test-extensions`.
4. For a change you can see, put before and after screenshots in the pull request.
5. Write commit messages that say what changes for people using OrbTorrent, such as "Show each peer's country flag in the Peers tab".

## Use a coding agent

Coding agents are welcome. The repository's [`AGENTS.md`](https://github.com/sanjevirau/OrbTorrent/blob/main/AGENTS.md) tells yours how OrbTorrent is built, tested and written, and what must stay true, such as extensions staying sandboxed. Claude Code reads it through `CLAUDE.md`. You're still the author:

- read every line before you send it, and try it in OrbTorrent Dev;
- say in the pull request which agent helped;
- keep it to one change, and to the issue it's for.

A pull request that nobody has read or tried may be closed without a review.

## Licence

By sending a pull request, you agree that your contribution is under the same licence as the code it changes: the GPL for the app, MIT for the SDK. There's no contributor licence agreement to sign.

## The name and icon

The name OrbTorrent and the orb icon aren't covered by the GPL. You're welcome to fork OrbTorrent, but please give your version its own name and icon, so people can tell it apart from the official app, and don't change them in a pull request.

## The layout

| Folder | Holds |
|---|---|
| `OrbTorrent/` | The SwiftUI app |
| `OrbTorrentTests/` | The app's tests |
| `ExtensionHost/` | `orb-extension-host`, the sandboxed helper that runs extensions |
| `extensions/` | The official extensions |
| `sdk/` | `@orbtorrent/api`: the extension API, the `orb` command and the templates |
| `skills/` | The Agent Skill for building extensions |
| `engine/` | The engine's build script, pinned versions and patches |
| `updates/` | `updates.orbtorrent.com`, the update feed |
| `website/` | orbtorrent.com and these docs |
| `docs/` | The development guide, and the extension system's design |
