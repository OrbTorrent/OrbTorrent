# @orbtorrent/api Changelog

## 1.1.0

Extension API 1.1, which needs an OrbTorrent that supports it. OrbTorrent says
so if it's too old.

- **`files.save(file, suffix, contents)`** adds a file next to one of a
  finished download's, named after it: `files.save(video, ".en.srt", text)`
  saves `Film.2024.en.srt` beside `Film.2024.mkv`. It needs the new
  permission `"files": "add"`, or `["contents", "add"]` with reading, which
  the install sheet shows as "Add files, such as subtitles, next to your
  downloads". Only subtitles, text, images and checksums, up to 10 MB each,
  and it never replaces a file, except one the same hook added before.
  OrbTorrent lists added files in the Checks tab, and moves and removes them
  with the download.
- **Bytes over the network.** A `fetch` response has `bytes()` and
  `arrayBuffer()`, for images and zip files, and `files.save` takes a
  `Uint8Array`.
- **`notify: true`** in a result also shows its summary as a notification.
- **`orb test`:** mocks can answer with `base64`; `expect` can check `saved`,
  `savedIncludes` and `notify`; and `download.alsoOnDisk` lists files already
  next to the download's. A file the user chose not to download isn't
  available to a hook, as in OrbTorrent.
- `AGENTS.md`, in new extensions and the Agent Skill, starts with what
  extensions can and can't do, so a coding agent can say before building when a
  request needs something they can't do yet.

## 1.0.4

- The docs moved to orbtorrent.com/docs/extensions. The npm pages, the
  README, `orb create`, `orb doctor` and new extensions' `AGENTS.md` link
  there, and to the docs in one file for language models,
  [llms-full.txt](https://orbtorrent.com/docs/extensions/llms-full.txt).
- `orb create` ends with a link to the getting-started guide.

## 1.0.3

- The docs, the npm pages and `npm create`'s help say
  `npm create @orbtorrent/extension@latest`. Without `@latest`, npm keeps
  running whichever version it cached first.

## 1.0.2

- `npm create @orbtorrent/extension` always makes the extension from the
  newest `@orbtorrent/api`. Before, npm could reuse an older one it had
  kept from an earlier run, with that version's template and `AGENTS.md`.
- `@orbtorrent/create-extension` now shares this package's version, and both
  are released together.

## 1.0.1

For building extensions with a coding agent. The extension API is unchanged.

- `orb doctor` checks Node.js, OrbTorrent and the extension, and says what to
  fix, including the steps only the user can take.
- `orb downloads` lists the downloads in OrbTorrent, to run a hook on.
- `orb install` packages the extension and asks OrbTorrent to install it.
  OrbTorrent shows what it does and what it can reach, and `orb install` waits
  for the user's answer. The installed copy replaces a development copy.
- `AGENTS.md` in new extensions covers them, and what only the user can do.
- New extensions start with `"version": "1.0.0"`, which OrbTorrent shows on
  their page.

## 1.0.0

The first version on npm. Runs in OrbTorrent with extension API 1.0.

- `beforeStart` and `afterFinish` hooks, and `verify` for settings.
- `fetch`, `files.sha256`, `files.formData`, `progress`, `storage`,
  `getPreferenceValues`, `environment` and `sleep`.
- `orb create`, `build`, `test`, `lint`, `dev`, `run` and `package`, each with
  `--json`.
- The `before-start` and `after-finish` templates, with an `AGENTS.md` for
  coding agents.
- MIT licensed, so extensions can use any licence.
