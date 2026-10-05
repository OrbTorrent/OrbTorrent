# VirusTotal Scan: notes for coding agents

This folder is an **OrbTorrent extension**. OrbTorrent is a BitTorrent app for
macOS. An extension hooks into moments in a download's life, like a check on a
pull request: it can look at a download **before it starts** and hold it, act
on it **after it finishes**, or pass on what the checks found **once they're
done**. Its result shows in the download's Checks tab.

This file has what you need. The full docs are at
https://orbtorrent.com/docs/extensions, and in one file at
https://orbtorrent.com/docs/extensions/llms-full.txt.

## What extensions can do, and can't yet

Check what the user asked for against this list before you build. If it needs
something extensions can't do, say so in your first reply, and offer what fits.

- **Can:** see a download's file names and sizes; hold it before it starts;
  fingerprint and upload its files once it finishes; make HTTPS requests to the
  hosts it lists; add files such as subtitles, artwork or checksums next to a
  finished download's files; show a result with details and a link, and as a
  notification, and mark the files it's about; tell which files are new when
  the user chose more of a download later; see what the other checks found
  once they're done, such as to send it to the user's phone; keep a little
  storage; have settings.
- **Can't yet:** change, rename, move or delete files, or unpack archives; read
  a file's contents itself; change the download (pause it, label it, skip
  files); reach this Mac or the local network, such as Plex, Sonarr or a NAS;
  run programs; act at other moments than before a download starts, after it
  finishes, and once its checks are done.
- **For what extensions can't do,** OrbTorrent can run a program or script of
  the user's own when a download finishes. Only the user can choose it, in
  OrbTorrent's **Settings › Downloads › When a Download Finishes**, because it
  runs as them, outside the sandbox. You can write the script for them:
  https://orbtorrent.com/docs/guides/run-a-program.

## The loop

Work in this order, and don't stop at a green build:

1. Change `package.json` and `src/`.
2. `npx orb test --json`: runs every file in `tests/` without OrbTorrent. Add a
   test for each behaviour you add, including downloads that must **pass**.
3. `npx orb build --json`: validates `package.json`, type-checks and bundles
   into `dist/`.
4. `npx orb lint --json`: ESLint with OrbTorrent's rules.
5. `npx orb doctor --json`: checks Node.js, OrbTorrent and this folder. A check
   with `"ok": false` needs fixing, and its `fix` says how, including when only
   the user can do it.
6. `npx orb downloads --json`, then
   `npx orb run <hook> --download "<name or info hash>" --json`: runs the hook
   on one of the user's downloads in OrbTorrent. An `afterFinish` hook needs a
   finished download, and an `afterChecks` hook a finished or held one.
7. When it does what the user asked, `npx orb install --json`: OrbTorrent shows
   what the extension does and what it can reach, and waits for the user. The
   command returns `"installed": true` once they've installed it, or fails if
   they chose not to. Tell the user to look at OrbTorrent before you run it.

Every command takes `--json`, never prompts, and exits with 1 when something's
wrong. `npx orb dev` keeps the extension loaded and rebuilds on every save; the
user runs that one.

### What only the user can do

OrbTorrent keeps three steps for the user, so nothing reaches their torrent app
without them. Ask for each one when `orb doctor` or a command says so, and never
try to get around them:

- Turn on **Allow development extensions**: in OrbTorrent, **Extensions** at the
  bottom of the sidebar, then the **Develop** tab.
- Allow the folder, when OrbTorrent asks the first time `orb run` or `orb dev`
  loads it.
- Confirm the install, after `orb install` opens it in OrbTorrent.

## Where the code runs

Extensions run in OrbTorrent's **sandboxed extension host** (JavaScriptCore),
not Node.js and not a browser. A fresh sandboxed process runs each hook, and it
exits afterwards.

- **Available:** the JavaScript language (ES2023 and newer), plus `console`,
  `setTimeout`/`setInterval`, `queueMicrotask`, `URL`, `URLSearchParams`,
  `TextEncoder`/`TextDecoder` (UTF-8 only), `atob`/`btoa`,
  `crypto.randomUUID()`/`crypto.getRandomValues()` and `structuredClone`.
- **Not available:** `fs`, `path`, `process`, `Buffer`, `require`, the global
  `fetch`, the DOM, and npm packages that need them. `orb build` refuses Node.js
  modules and says what to use instead.
- **Everything else goes through `@orbtorrent/api`.** That covers the network,
  the download's files, storage, progress and settings. OrbTorrent checks each
  call against `permissions` in `package.json`.

## package.json

| Field | Meaning |
|---|---|
| `name` | Unique id: lowercase letters, digits and hyphens. |
| `title`, `description`, `author`, `icon` | Shown on OrbTorrent's Extensions page. `icon` is a 512×512 PNG in `assets/`. |
| `version` | Such as `1.0.0`, shown on its page. Raise it with each change you install or share. |
| `hooks` | `[{ "name", "title", "description"?, "event" }]`. `event` is `beforeStart`, `afterFinish` or `afterChecks`. A hook named `check` is the default export of `src/check.ts`. |
| `permissions.files` | `"contents"` lets it fingerprint and upload the download's files, and `"add"` lets it add files next to them. `["contents", "add"]` for both. Names and sizes are always given. |
| `permissions.network` | Exact host names, such as `["www.virustotal.com"]`. Only HTTPS on port 443, and never local addresses. |
| `preferences` | Settings OrbTorrent draws: `{ "name", "type", "title", "description"?, "required"?, "placeholder"?, "default"?, "label"? (checkbox), "data"? (dropdown: [{ "title", "value" }]) }`. Types: `textfield`, `password`, `checkbox`, `dropdown`. |
| `verify` | Names `src/<verify>.ts`, which checks the settings when the user presses Verify. |

Users see what an extension can do from `hooks` and `permissions`, so ask only
for what it needs.

## Hooks

```ts
import { Download, Result } from "@orbtorrent/api";

export default async function check(download: Download): Promise<Result> {
  return { status: "passed", summary: "Looks like a real release" };
}
```

| | `beforeStart` | `afterFinish` | `afterChecks` |
|---|---|---|---|
| Runs | Once the file list is known, before any data downloads | Each time every wanted file has finished | Once the other checks are done: after it finishes, and when one holds it |
| Can hold the download | Yes: `failed` holds it until the user decides | No, it reports | No, it reports on the checks |
| Sees other checks' results | No | No | Yes, in `download.checks` |
| File contents | Not yet: the files don't exist | Yes, with `"files": "contents"` | Once it's finished, with `"files": "contents"` |
| Time limit | 15 s (10 s of CPU) | 6 h (2 min of CPU; waiting doesn't count) | 6 h (2 min of CPU) |
| Memory | 512 MB | 512 MB | 512 MB |

A user who downloads some of a download's files and chooses more later
finishes it again, and `afterFinish` and `afterChecks` hooks run again on every
finished file. `isNew` marks the files that finished since the hook last ran.

A hook that throws, crashes or runs out of time shows **Didn't finish**. A
`beforeStart` hook that doesn't finish lets the download start: a broken
extension never blocks downloads.

```ts
interface Download {
  id: string;        // info hash
  name: string;
  size: number;      // bytes of wanted files
  isPrivate: boolean;
  files: { index: number; path: string; size: number; wanted: boolean; isNew?: boolean }[];  // path is relative; isNew once finished
  checks?: CheckResult[];  // afterChecks only: other extensions' results, worst first
  isHeld?: boolean;        // afterChecks only: a check is holding it, so no files are on disk
}

interface CheckResult {
  extension: { name: string; title: string };
  hook: string;
  event: "beforeStart" | "afterFinish";
  status: "passed" | "warning" | "failed" | "skipped" | "didNotFinish";
  summary: string;
  details?: string;
  link?: { title: string; url: string };
  files?: { index: number; path: string; status: "passed" | "warning" | "failed"; summary?: string }[];
}

interface Result {
  status: "passed" | "warning" | "failed" | "skipped";
  summary: string;                          // one line, shown in the list
  details?: string;                         // markdown: paragraphs, "- " lists, **bold**, `code`, [links](https://…); no tables
  link?: { title: string; url: string };
  notify?: boolean;                         // also show the summary as a notification
  files?: { file: DownloadFile | number; status: "passed" | "warning" | "failed"; summary?: string; link?: { title: string; url: string } }[];
}
```

`files` marks the files a result is about, beside each file in OrbTorrent. A
result counts as no better than its worst file, and replaces the hook's last
one, so name every file you know about, not only the new ones.

A warning or failure after a download finishes, and a download held before it
starts, are notifications already. Set `notify: true` for news the user would
want without opening the Checks tab, such as "Added English subtitles".

- **passed:** nothing wrong.
- **warning:** worth a look. The download carries on and gets a badge.
- **failed:** something is wrong. Before a download starts, this holds it.
- **skipped:** the check didn't apply or couldn't run, for example with no
  network or at a service's daily limit.

## The API (`@orbtorrent/api`)

```ts
fetch(url, { method?, headers?, body? }): Promise<Response>
  // HTTPS to a host in permissions.network. body is text (JSON.stringify for JSON),
  // or files.formData(...). Response: status, ok, url, headers.get(), text(), json(),
  // bytes() and arrayBuffer() for images and zip files.
  // Responses are limited to 10 MB; each request times out after 30 s.
files.sha256(file): Promise<string>        // lowercase hex; once finished; needs "files": "contents"
files.formData({ field: "text", file: download.files[0] }): FormBody   // upload with fetch
files.save(file, suffix, contents): Promise<{ path, size }>
  // once finished; needs "files": "add". Saves next to `file`, named after it:
  // files.save(video, ".en.srt", text) saves Film.2024.en.srt beside Film.2024.mkv.
  // contents is text (saved as UTF-8) or a Uint8Array.
progress({ done?, total?, message? }): Promise<void>                   // shown in the Checks tab
storage.get(key) / set(key, value) / remove(key) / keys()             // JSON, up to 1 MB, kept across runs
getPreferenceValues(): OrbPreferences     // every setting has a value; types come from orb-env.d.ts
environment.extensionName / isDevelopment / entryPoint / apiVersion
sleep(milliseconds): Promise<void>        // waiting doesn't use CPU time
```

### Adding files

`files.save` adds a file next to one of the download's, in the same folder and
named after it, so players and media servers find it.

- **The suffix** starts with `.`, `-`, `_` or a space, and ends with an
  extension: `.en.srt`, `.forced.srt`, `-poster.jpg`, `.nfo`.
- **Only files that can't run:** subtitles (`.srt .ass .ssa .vtt .sub .idx
  .sup .smi .lrc`), text (`.txt .nfo .md .json .xml .csv .cue`), images (`.jpg
  .jpeg .png .webp .gif .heic`) and checksums (`.sfv .md5 .sha1 .sha256`).
- **It never replaces a file,** except one the same hook added to the same
  download before, such as when the user runs it again. If a subtitle is
  already there, `files.save` throws: catch it and report what was there.
- **Up to 10 MB a file, and 200 files and 50 MB a run.**
- OrbTorrent lists the files in the Checks tab, and moves and removes them with
  the download.

`verify` gets the settings and returns `{ ok: true, message? }` or
`{ ok: false, message }`:

```ts
import { VerifyResult } from "@orbtorrent/api";

export default async function verify(preferences: OrbPreferences): Promise<VerifyResult> {
  return preferences.apiKey ? { ok: true } : { ok: false, message: "Enter your API key." };
}
```

## Settings

- Every setting has a value when a hook runs: what the user chose, or its
  default, or else `""`, `false`, or a dropdown's first option.
- If a `required` setting is empty, the extension shows **Setup** and its hooks
  are skipped.
- `password` values are kept in the macOS Keychain and hidden in logs.
- Put setup steps (such as how to get an API key) in `help.md`. OrbTorrent shows
  it next to the settings.

## Tests

A test is a JSON file in `tests/`:

```json
{
  "name": "A program disguised as a film is held",
  "hook": "check",
  "download": {
    "name": "Film.2024.1080p.WEB-DL",
    "files": [{ "path": "Film.2024.1080p.mp4.exe", "size": 2400000, "sha256": "…" }]
  },
  "preferences": { "apiKey": "test-key" },
  "storage": {},
  "mocks": {
    "fetch": [
      { "method": "GET", "url": "https://www.virustotal.com/api/v3/files/*", "status": 200, "json": {} }
    ]
  },
  "expect": { "status": "failed", "summaryIncludes": "disguised" }
}
```

- **What a test can include:**
  - `hook`, which can be left out when there's only one hook;
  - `"verify": true`, which runs `verify` with `preferences` instead;
  - `download.files[].sha256`, which answers `files.sha256`;
  - `download.alsoOnDisk`, paths of other files already next to the download's,
    which `files.save` won't replace;
  - `download.files[].isNew`, `true` unless it says otherwise once the download
    has finished;
  - for an `afterChecks` hook, `download.checks`, other extensions' results,
    whose files can be named by `path` alone, and `"held": true` for a held
    download;
  - `mocks.fetch`, where `*` in a URL matches any text, and `"times": 1` makes a
    mock answer once before the next matching one does (a rate limit, then
    success). A mock answers with `json`, `text`, or `base64` for bytes. An
    unmatched request fails the test and says so.
  - Timers run on a virtual clock, so waiting out a rate limit takes no time.
- **What `expect` can check:**
  - `status`;
  - `summaryIncludes` (case-insensitive) and `summaryMatches` (a regex);
  - `detailsIncludes`;
  - `fetched`, the URLs requested;
  - `saved`, the paths of files it added, and `savedIncludes`, text in each;
  - `notify`, whether the result asks to be a notification;
  - `files`, each file's status by path (`*` matches any text), or `"none"`;
  - `throws`, part of the error message;
  - `ok` and `messageIncludes`, for `verify`;
  - `not`, which inverts any of the others.
- **Where tests run:** `orb test` runs the hook in a Node `vm` context set up like
  OrbTorrent's host. OrbTorrent answers requests the same way, with the same
  error messages. Node's engine isn't JavaScriptCore, so use `orb run` to confirm
  on the real thing.

## Rules for good results

- **Check as early as you can.** A download's names and sizes are known before
  it starts, so a check on them belongs in `beforeStart`, where it can save the
  user a download. Use `afterFinish` to read file contents, or to act once a
  download is done, such as adding its subtitles. Use `afterChecks` to pass on
  what the checks found.
- **Mark the files you mean** in `files`, and report every file you know
  about in each run. Use `isNew` to skip work you did on an earlier run.
- **Write the summary in plain words, and say which file and why.** For example:
  "Contains a program disguised as a video: Film.mp4.exe". Use sentence case,
  with no full stop.
- **Use `failed` only when you're sure.** Use `warning` for "worth a look". A
  false alarm that holds a download is worse than a missed warning.
- **In `beforeStart`, a network error or timeout means `skipped`**, never
  `failed`.
- **Respect rate limits.** `sleep` between requests, report `progress` on long
  runs, and keep answers in `storage` so a rerun doesn't repeat work.
- **Add only what was asked for, next to the file it's for.** One subtitle per
  video in the user's language, not every language there is.
- **Don't log API keys or file contents.**

## Errors and fixes

| Message | Fix |
|---|---|
| `Request to <host> was refused. Add "<host>" to permissions.network…` | Add the exact host to `permissions.network`. |
| `Reading files isn't allowed…` | Add `"files": "contents"` to `permissions`. |
| `File N isn't available: it isn't downloaded yet…` | File contents only exist once a download has finished, in `afterFinish` hooks or `afterChecks` hooks when it isn't held, and only for files the user chose to download. |
| `Its result's "files" names a file that isn't part of this download…` | Name only files from `download.files`, or their `index`. |
| `Adding files isn't allowed…` | Add `"files": "add"` to `permissions`, or `["contents", "add"]`. |
| `"<name>" already exists. An extension can't replace a file it didn't add.` | Something is there already, such as subtitles that came with the download: report it, and don't retry. |
| `Extensions can't add .<x> files…` | Only subtitles, text, images and checksums. |
| `"fs" is a Node.js module, and extensions don't run in Node.js…` | Use the API named in the message. |
| `The hook "x" needs src/x.ts.` | Name the file after the hook, or rename the hook. |
| `The test has no mock for GET https://…` | Add that URL to the test's `mocks.fetch`. |
| `OrbTorrent isn't reachable.` | Run `npx orb doctor --json` and do what its `fix` says. |
