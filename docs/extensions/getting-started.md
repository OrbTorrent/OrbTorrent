# Getting started

You need Node.js 22.13 or later and OrbTorrent.

## Make an extension

```sh
npm create @orbtorrent/extension size-guard
cd size-guard
npm install
```

There are two templates:

- `before-start` (the default) holds downloads bigger than a limit you choose.
- `after-finish` sends a notification to your phone through ntfy when a
  download finishes. Choose it with
  `npm create @orbtorrent/extension notify-me -- --template after-finish`.

The extension depends on [`@orbtorrent/api`](https://www.npmjs.com/package/@orbtorrent/api),
which has the API and `orb`, the command-line tool its scripts use. It's MIT
licensed, so your extension can use any licence. In a clone of this repository,
`node sdk/bin/orb.js create size-guard` makes one that uses the SDK in the
clone instead.

The new folder has:

```
size-guard/
├── package.json     the manifest: hooks, permissions, settings
├── src/check.ts     the hook, named after it
├── tests/           JSON tests that run without OrbTorrent
├── assets/icon.png
├── AGENTS.md        everything in one file, for coding agents
└── README.md, CHANGELOG.md, tsconfig.json
```

## The loop

```sh
npm test          # orb test: runs tests/*.json without OrbTorrent
npm run build     # orb build: validates, type-checks and bundles into dist/
npm run lint      # orb lint: ESLint with OrbTorrent's rules
npm run dev       # orb dev: loads it into OrbTorrent and rebuilds on every save
```

`orb dev` and `orb run` need OrbTorrent open, with **Allow development
extensions** on. It's on the **Develop** tab of the **Extensions** page, in the
sidebar of OrbTorrent's main window. The first time a folder connects, OrbTorrent
asks before loading it. `npx orb doctor` checks all of this, and says what's
missing.

To try a hook on one of your downloads, list them, then run it on one:

```sh
npx orb downloads
npx orb run check --download "Name or info hash"
```

When it's ready, `npx orb install` packages it and asks OrbTorrent to install
it. OrbTorrent shows what it does and what it can reach, and installs it when
you confirm, replacing the development copy. `orb install` waits for your
answer, so a coding agent knows when it's done.

Every command takes `--json` for output a script or coding agent can read, and
exits with 1 when something's wrong.

## With a coding agent

Coding agents such as Claude Code, Codex, Cursor and Gemini CLI can do all of
this for you. On OrbTorrent's **Develop** tab, **Build with AI** turns what you
want the extension to do into a request to paste into your agent. It covers every
step above. Along the way, you're asked to turn on development extensions, to
allow the agent's folder, and to confirm the install.

## Next

- [Hooks](hooks.md) for when your code runs.
- [API](api.md) for reaching the network, files and storage.
- [Testing](testing.md) for faking the network in tests.
