# {{title}}: notes for coding agents

This folder is an **OrbTorrent extension**. OrbTorrent is a BitTorrent app for
macOS. An extension hooks into moments in a download's life, like a check on a
pull request: it can look at a download **before it starts** and hold it, or act
on it **after it finishes**. Its result shows in the download's Checks tab.

## The loop

Work in this order, and don't stop at a green build:

1. Change `package.json` and `src/`.
2. `npx orb test --json`: runs every file in `tests/` without OrbTorrent. Add a
   test for each behaviour you add, including downloads that must **pass**.
3. `npx orb build --json`: validates `package.json`, type-checks and bundles
   into `dist/`.
4. `npx orb lint --json`: ESLint with OrbTorrent's rules.
5. `npx orb run <hook> --download "<name or info hash>" --json`: runs the hook
   on a real download in OrbTorrent. This needs OrbTorrent open with
   **Allow development extensions** on: it's on the **Develop** tab of the
   **Extensions** page, in the sidebar of OrbTorrent's main window. The first time, the user has to
   allow the folder in OrbTorrent.

Every command takes `--json`, never prompts, and exits with 1 when something's
wrong. `npx orb dev` keeps the extension loaded and rebuilds on every save; the
user runs that one.

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
| `hooks` | `[{ "name", "title", "description"?, "event" }]`. `event` is `beforeStart` or `afterFinish`. A hook named `check` is the default export of `src/check.ts`. |
| `permissions.files` | `"contents"` lets it fingerprint and upload the download's files. Names and sizes are always given. |
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

| | `beforeStart` | `afterFinish` |
|---|---|---|
| Runs | Once the file list is known, before any data downloads | Once every wanted file has finished |
| Can hold the download | Yes: `failed` holds it until the user decides | No, it reports |
| File contents | Not yet: the files don't exist | Yes, with `"files": "contents"` |
| Time limit | 15 s (10 s of CPU) | 6 h (2 min of CPU; waiting doesn't count) |
| Memory | 512 MB | 512 MB |

A hook that throws, crashes or runs out of time shows **Didn't finish**. A
`beforeStart` hook that doesn't finish lets the download start: a broken
extension never blocks downloads.

```ts
interface Download {
  id: string;        // info hash
  name: string;
  size: number;      // bytes of wanted files
  isPrivate: boolean;
  files: { index: number; path: string; size: number; wanted: boolean }[];  // path is relative
}

interface Result {
  status: "passed" | "warning" | "failed" | "skipped";
  summary: string;                          // one line, shown in the list
  details?: string;                         // markdown: paragraphs, "- " lists, **bold**, `code`, [links](https://…); no tables
  link?: { title: string; url: string };
}
```

- **passed:** nothing wrong.
- **warning:** worth a look. The download carries on and gets a badge.
- **failed:** something is wrong. Before a download starts, this holds it.
- **skipped:** the check didn't apply or couldn't run, for example with no
  network or at a service's daily limit.

## The API (`@orbtorrent/api`)

```ts
fetch(url, { method?, headers?, body? }): Promise<Response>
  // HTTPS to a host in permissions.network. body is text (JSON.stringify for JSON),
  // or files.formData(...). Response: status, ok, url, headers.get(), text(), json().
  // Responses are limited to 10 MB; each request times out after 30 s.
files.sha256(file): Promise<string>        // lowercase hex; afterFinish only; needs "files": "contents"
files.formData({ field: "text", file: download.files[0] }): FormBody   // upload with fetch
progress({ done?, total?, message? }): Promise<void>                   // shown in the Checks tab
storage.get(key) / set(key, value) / remove(key) / keys()             // JSON, up to 1 MB, kept across runs
getPreferenceValues(): OrbPreferences     // every setting has a value; types come from orb-env.d.ts
environment.extensionName / isDevelopment / entryPoint / apiVersion
sleep(milliseconds): Promise<void>        // waiting doesn't use CPU time
```

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
  - `mocks.fetch`, where `*` in a URL matches any text, and `"times": 1` makes a
    mock answer once before the next matching one does (a rate limit, then
    success). An unmatched request fails the test and says so.
  - Timers run on a virtual clock, so waiting out a rate limit takes no time.
- **What `expect` can check:**
  - `status`;
  - `summaryIncludes` (case-insensitive) and `summaryMatches` (a regex);
  - `detailsIncludes`;
  - `fetched`, the URLs requested;
  - `throws`, part of the error message;
  - `ok` and `messageIncludes`, for `verify`;
  - `not`, which inverts any of the others.
- **Where tests run:** `orb test` runs the hook in a Node `vm` context set up like
  OrbTorrent's host. OrbTorrent answers requests the same way, with the same
  error messages. Node's engine isn't JavaScriptCore, so use `orb run` to confirm
  on the real thing.

## Rules for good results

- **Write the summary in plain words, and say which file and why.** For example:
  "Contains a program disguised as a video: Film.mp4.exe". Use sentence case,
  with no full stop.
- **Use `failed` only when you're sure.** Use `warning` for "worth a look". A
  false alarm that holds a download is worse than a missed warning.
- **In `beforeStart`, a network error or timeout means `skipped`**, never
  `failed`.
- **Respect rate limits.** `sleep` between requests, report `progress` on long
  runs, and keep answers in `storage` so a rerun doesn't repeat work.
- **Don't log API keys or file contents.**

## Errors and fixes

| Message | Fix |
|---|---|
| `Request to <host> was refused. Add "<host>" to permissions.network…` | Add the exact host to `permissions.network`. |
| `Reading files isn't allowed…` | Add `"files": "contents"` to `permissions`. |
| `File N isn't available: it isn't downloaded yet…` | File contents only exist in `afterFinish` hooks. |
| `"fs" is a Node.js module, and extensions don't run in Node.js…` | Use the API named in the message. |
| `The hook "x" needs src/x.ts.` | Name the file after the hook, or rename the hook. |
| `The test has no mock for GET https://…` | Add that URL to the test's `mocks.fetch`. |
| `OrbTorrent isn't reachable.` | Ask the user to open OrbTorrent and allow development extensions. |
