# @orbtorrent/api Changelog

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
