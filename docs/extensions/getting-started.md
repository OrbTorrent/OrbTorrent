# Getting started

You need Node.js 22.13 or later and OrbTorrent.

## Make an extension

`orb` comes with `@orbtorrent/api`. Until it's on npm, run it from this
repository:

```sh
npm install                       # in the repository, once
node sdk/bin/orb.js create size-guard
cd size-guard
npm install
```

There are two templates:

- `--template before-start` (the default) holds downloads bigger than a limit
  you choose.
- `--template after-finish` sends a notification to your phone through ntfy
  when a download finishes.

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
asks before loading it.

To try a hook on one of your downloads:

```sh
npx orb run check --download "Name or info hash"
```

Every command takes `--json` for output a script or coding agent can read, and
exits with 1 when something's wrong.

## Next

- [Hooks](hooks.md) for when your code runs.
- [API](api.md) for reaching the network, files and storage.
- [Testing](testing.md) for faking the network in tests.
