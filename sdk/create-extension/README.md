# @orbtorrent/create-extension

Makes a new extension for [OrbTorrent](https://orbtorrent.com), the BitTorrent
app for macOS.

```sh
npm create @orbtorrent/extension size-guard
cd size-guard
npm install
```

There are two templates:

- `before-start` (the default) looks at a download once its file list is
  known, before any of it downloads, and can hold it.
- `after-finish` acts on a download once it finishes. Choose it with
  `npm create @orbtorrent/extension notify-me -- --template after-finish`.

The new folder depends on [`@orbtorrent/api`](https://www.npmjs.com/package/@orbtorrent/api),
the API extensions use, and its `orb` command-line tool. Its README and the
folder's `AGENTS.md` explain the rest.

MIT licensed.
