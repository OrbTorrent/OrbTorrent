---
name: build-orbtorrent-extension
description: Build, test and debug extensions for OrbTorrent, the macOS BitTorrent app. Extensions are TypeScript hooks that check a download before it starts (and can hold it) or act on it after it finishes. Use when creating or changing an OrbTorrent extension, writing its tests, or using the orb command-line tool.
license: MIT
---

# Build an OrbTorrent extension

An OrbTorrent extension is a folder with a `package.json` manifest and one
TypeScript file per hook in `src/`. It runs in OrbTorrent's sandboxed extension
host (JavaScriptCore), not Node.js: everything outside the JavaScript language
goes through `@orbtorrent/api`, which OrbTorrent checks against the manifest's
permissions.

## Steps

1. **Check that extensions can do what's asked.** They can't change, move or
   delete files, change the download, reach the local network or run
   programs: `references/AGENTS.md` lists what they can and can't do. Say so
   first if the request needs one of those. OrbTorrent can run a script of the
   user's own when a download finishes, which only they can set up.
2. **Start from a template, unless you're changing an existing extension.**
   Run `npm create @orbtorrent/extension@latest <name> -- --template before-start|after-finish`,
   then `npm install` in the new folder.
3. **Read `references/AGENTS.md`.** It covers the API, the manifest, the hooks,
   the test format, the rules for good results, and the errors you'll see with
   their fixes. An extension made with `orb create` has the same file. The
   full docs are at https://orbtorrent.com/docs/extensions, and all of them in
   one file at https://orbtorrent.com/docs/extensions/llms-full.txt.
4. **Write the hook and a test for each behaviour**, including downloads that
   must pass.
5. **Loop until everything passes:**
   - `npx orb test --json`
   - `npx orb build --json`
   - `npx orb lint --json`

   Every command takes `--json`, never prompts, and exits with 1 on failure.
6. **Check OrbTorrent is ready** with `npx orb doctor --json`. A check with
   `"ok": false` needs fixing, and its `fix` says how. Some steps only the user
   can take in OrbTorrent: ask them, and never try to get around them.
7. **Confirm on a real download:** `npx orb downloads --json` lists them, then
   `npx orb run <hook> --download "<name>" --json`. The first time, OrbTorrent
   asks the user to allow the folder.
8. **Install it** once it does what the user asked: `npx orb install --json`
   shows the install sheet in OrbTorrent, and returns `"installed": true` once
   the user has confirmed it.

## Key facts

- Hooks are `beforeStart` (15 s; `failed` holds the download), `afterFinish`
  (6 h; file contents available; runs again when the user chooses more files,
  with `isNew` on the ones that just finished) or `afterChecks` (reports on the
  other checks in `download.checks`, after they finish or when one holds it,
  with `download.isHeld`).
- A hook returns `{ status: "passed" | "warning" | "failed" | "skipped", summary, details?, link?, notify?, files? }`.
  The summary is one line that says which file and why. `notify: true` also
  shows it as a notification. `files: [{ file, status, summary }]` marks the
  files it's about in OrbTorrent.
- Network access needs each exact host in `permissions.network`. Reading files
  needs `"files": "contents"`, and adding them `"files": "add"`.
- `files.save(file, ".en.srt", contents)` adds a file next to a finished
  download's file, named after it: only subtitles, text, images and
  checksums, and never replacing a file it didn't add.
- There's no `fs`, `process`, `Buffer`, `require`, global `fetch` or DOM. Use
  `fetch`, `files`, `storage`, `progress` and `getPreferenceValues` from
  `@orbtorrent/api`.
- Tests mock the network (`mocks.fetch`, with `*` and `times`) and run on a
  virtual clock.
