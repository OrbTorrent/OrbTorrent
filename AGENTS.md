# OrbTorrent

A Mac app for downloading torrents: SwiftUI around qBittorrent's engine, with
extensions in TypeScript that run sandboxed. This file is for coding agents
working on it. People start with [CONTRIBUTING.md](CONTRIBUTING.md), and
[docs/development.md](docs/development.md) explains how it's built.

## Before writing code

- **Anything bigger than a small fix needs an issue** where the approach was
  agreed. If there isn't one, tell the person you're working with before you
  start.
- **Check [ROADMAP.md](ROADMAP.md).** It lists what's planned and what's been
  decided against, with the reasons. Don't build what it says no to.
- **One change per pull request.** Don't tidy, rename or reformat code you
  aren't changing.

## Building and testing

```sh
brew install cmake ninja xcodegen   # once, with Xcode 26 and Node.js 22.13 or later
make engine            # the engine, once (about 15 minutes)
make dev               # build OrbTorrent Dev and open it
make test              # the app's tests
make test-extensions   # the extension SDK, the official extensions and their scripts
```

- **Work in OrbTorrent Dev.** It has its own library, settings and Keychain
  items, so it runs beside the person's own OrbTorrent. Never quit, replace or
  change their OrbTorrent or its files in
  `~/Library/Application Support/OrbTorrent`. So no `make install`: it
  replaces the OrbTorrent in `/Applications`.
- **Add tests for what you change,** and run them: Swift Testing in
  `OrbTorrentTests/`, `node:test` in `sdk/test/` and `scripts/`, and `orb test`
  files in each official extension's `tests/`.
- **`OrbTorrent.xcodeproj` is generated** from `project.yml` by `make project`.
  Change `project.yml`, never the project.
- **The website and docs** are in `website/`, with their own
  [AGENTS.md](website/AGENTS.md). `npm run build` there checks every link
  between docs pages.

## Writing it

- **Match the code around your change:** its naming, structure and amount of
  comments. The app is Swift 6, with complete concurrency checking.
- **Don't add a dependency,** a Swift package or an npm package, unless the
  issue agreed to it.
- **Text people see in the app is short, plain English,** like the text around
  it. Buttons and menu items are in title case, such as **Show in Finder**,
  and names are in curly quotes, such as “Downloads”. A message about a
  problem says what happened and what to do.
- **Docs are plain British English,** and every fact in them is checked against
  the code.
- **Change the docs with the code.** A change to the extension API changes
  `sdk/src/index.ts`, its page
  `website/src/content/docs/docs/extensions/reference/api.md` and
  `sdk/CHANGELOG.md` together.

## What must stay true

- **Extensions stay sandboxed.** They run in `orb-extension-host`
  (`ExtensionHost/`), which has the App Sandbox and only JavaScriptCore's JIT
  besides, and OrbTorrent checks every request against the extension's
  permissions (`OrbTorrent/Extensions/`). They can't run programs, reach this
  Mac or its local network, or touch files they weren't allowed. A change to
  what extensions can do needs an issue first. See
  [Security model](https://orbtorrent.com/docs/extensions/security).
- **Some choices are only the person's.** Installing an extension, allowing a
  folder of extensions in development, and choosing a program to run when a
  download finishes happen in OrbTorrent's own windows, by the person. Nothing
  else may make them: not code, an extension, the `orb` tool or a settings
  file.
- **The engine stays private.** Its Web API listens on 127.0.0.1 only, behind a
  random password, and its own way of running programs stays off.
- **OrbTorrent sends nothing new.** Everything it sends is listed on
  [orbtorrent.com/privacy](https://orbtorrent.com/privacy). Sending anything
  more is a decision for an issue, and changes every place
  [website/AGENTS.md](website/AGENTS.md) lists.
- **The name OrbTorrent and the orb icon stay as they are.** They aren't under
  the GPL.

## Files made from other files

- **The extension `AGENTS.md`** in each official extension and in
  `skills/build-orbtorrent-extension/references/` is a copy of
  `sdk/templates/_shared/AGENTS.md`. Change the template, then run
  `node scripts/extension-docs.mjs`.
- **`llms.txt`** and the docs' Markdown copies are built with the website.

## Sending it

- **Commit messages say what changes for people using OrbTorrent,** in the
  imperative and without prefixes, such as "Show each peer's country flag in
  the Peers tab".
- **Fill in the pull request template,** and say which coding agent helped.
  The person sending it must have read every line and tried it in OrbTorrent
  Dev, so tell them what to try.
- **For a change you can see,** add before and after screenshots of OrbTorrent
  Dev, with only legal torrents and no one else's IP addresses in them.
- **Never commit secrets:** API keys, signing keys, tokens, tracker passkeys or
  personal email addresses.
- **A new official extension** starts with an issue, made with the "Propose an
  official extension" form. To list an extension in the README instead, follow
  [Your own extension](CONTRIBUTING.md#your-own-extension).
