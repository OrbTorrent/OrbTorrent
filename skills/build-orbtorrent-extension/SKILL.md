---
name: build-orbtorrent-extension
description: Build, test and debug extensions for OrbTorrent, the macOS BitTorrent app. Extensions are TypeScript hooks that check a download before it starts (and can hold it) or act on it after it finishes. Use when creating or changing an OrbTorrent extension, writing its tests, or using the orb command-line tool.
license: GPL-3.0-or-later
---

# Build an OrbTorrent extension

An OrbTorrent extension is a folder with a `package.json` manifest and one
TypeScript file per hook in `src/`. It runs in OrbTorrent's sandboxed extension
host (JavaScriptCore), not Node.js: everything outside the JavaScript language
goes through `@orbtorrent/api`, which OrbTorrent checks against the manifest's
permissions.

## Steps

1. **Start from a template, unless you're changing an existing extension.**
   Run `npx orb create <name> --template before-start|after-finish`, then
   `npm install` in the new folder.
2. **Read `references/AGENTS.md`.** It covers the API, the manifest, the hooks,
   the test format, the rules for good results, and the errors you'll see with
   their fixes. An extension made with `orb create` has the same file.
3. **Write the hook and a test for each behaviour**, including downloads that
   must pass.
4. **Loop until everything passes:**
   - `npx orb test --json`
   - `npx orb build --json`
   - `npx orb lint --json`

   Every command takes `--json`, never prompts, and exits with 1 on failure.
5. **When OrbTorrent is open,** confirm on a real download with
   `npx orb run <hook> --download "<name>" --json`. The user needs
   **Allow development extensions** on (on the Develop tab of OrbTorrent's
   **Extensions** page), and has to
   allow the folder the first time.

## Key facts

- Hooks are `beforeStart` (15 s; `failed` holds the download) or `afterFinish`
  (6 h; file contents available).
- A hook returns `{ status: "passed" | "warning" | "failed" | "skipped", summary, details?, link? }`.
  The summary is one line that says which file and why.
- Network access needs each exact host in `permissions.network`. Reading files
  needs `"files": "contents"`.
- There's no `fs`, `process`, `Buffer`, `require`, global `fetch` or DOM. Use
  `fetch`, `files`, `storage`, `progress` and `getPreferenceValues` from
  `@orbtorrent/api`.
- Tests mock the network (`mocks.fetch`, with `*` and `times`) and run on a
  virtual clock.
