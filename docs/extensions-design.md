# Extensions: design

Status: built, 28 September 2026. This was the proposal; what changed while
building it is under [What changed while building](#what-changed-while-building),
and the developer docs are in [docs/extensions](extensions).

## What we're building

Extensions hook into moments in a download's life, the way checks run on a GitHub
pull request. An extension can look at a download before it starts and hold it,
or act on it after it finishes, and its result shows on the download.

The first version has:

- two moments: **before a download starts** and **after it finishes**;
- two official extensions: **Fake Download Check** and **VirusTotal Scan**;
- an Extensions page in the main window, a Checks tab in the inspector, and
  settings for extensions, with secrets kept in the Keychain;
- extensions installed from a file, and development mode;
- tools for developers and coding agents: an `orb` CLI, templates with
  `AGENTS.md`, tests that run without the app, and docs as markdown.

Nothing is published in the first version: no store, no npm package, no website.
Those need accounts and come later.

### Goals

- Users can see, for each extension, what it does, when it runs, what it's
  allowed to do and what it found.
- Permissions are enforced, not just declared.
- A broken, slow or malicious extension can't hold downloads forever, read files
  it wasn't given, or reach websites it didn't declare.
- A developer or a coding agent can build and test an extension end to end from
  the terminal.

### Not in the first version

A store and publishing, subtitles, scripts in other languages, extensions that
draw their own UI, other moments (added, file finished, removed), an MCP server
for development, and a crash dashboard.

## What the user sees

### The Extensions page

Extensions are what sets OrbTorrent apart, so they have their own page in the
main window rather than a tab in Settings. **Extensions** sits in the sidebar,
pinned just above the speed card, with an orange warning when an extension
needs setup or couldn't load.

A switch at the top of the Installed tab turns every extension off, so
OrbTorrent works as a plain torrent client. While they're off, no hook runs,
the `orb dev` socket closes, and nothing about checks shows: no Checks tab,
badges, checks cards, held strip or **Install Extension…** menu item. The
sidebar row stays, reading "Off", and the page offers **Turn On Extensions**.
Each extension, its settings and past results are kept. Turning them off lets
go of downloads waiting on checks, asking first: one meant to start once its
checks passed starts, and one a check held stays paused. Turning them back on
counts each extension as turned on then, so what finished meanwhile isn't
checked at the next launch. Opening an `.orbext` file while they're off asks to
turn them on.

```
┌─ Extensions ────────── [ Installed | Activity (1) | Develop ] ─ [+] [Search] ─┐
│ Installed                                                                     │
│ ┌──────────────────────────────────────────────────────────────────────┐      │
│ │ Check downloads with extensions                                 (On) │      │
│ │ ──────────────────────────────────────────────────────────────────── │      │
│ │ (+) ─ [ Before it starts    ] ─── (↓) ─── [ After it finishes ] ─(✓) │      │
│ │ Added [ Fake Download Check ] Downloading [ VirusTotal Scan ! ] Done │      │
│ └──────────────────────────────────────────────────────────────────────┘      │
│ Official                                                                      │
│ ┌ Fake Download Check    (On) ┐  ┌ VirusTotal Scan           (Off) ┐          │
│ │ Holds downloads that look…  │  │ Checks finished downloads…      │          │
│ │ Before it starts  Checked 3 │  │ After it finishes           Off │          │
│ └─────────────────────────────┘  └─────────────────────────────────┘          │
│ Installed by You                                   Install Extension…         │
│                                                                               │
│ Activity                                                                      │
│ [ Holding a download before it starts: Film.2024… (Fake…)   Review ]          │
│ [ All Checks | Problems ]  [ All Extensions ▾ ]            12 checks          │
│ Status   Download            Extension        Result            When          │
│ Failed   Film.2024.1080p…    Fake Download…   Contains a prog…  2m            │
│ Passed   ubuntu-26.04.1…     VirusTotal Scan  No engine flag…   1h            │
│                                                                               │
│ Develop                                                                       │
│ Development  [ Allow development extensions (On) ] orb dev connected          │
│ Loaded for Development   size-guard   ~/code/size-guard   Reload              │
│ Get Started   1 create  2 npm test  3 npm run dev  4 orb run  5 share         │
│ For Coding Agents · Documentation (beside, on wide windows)                   │
└───────────────────────────────────────────────────────────────────────────────┘
```

The page has three tabs, in a segmented control in the toolbar, so each job
has room:

- **Installed** (the default) manages extensions. A strip at the top shows a
  download's life and the extensions that are on at each point, which explains
  hooks without words; each one opens its page. Below it are cards for the
  Official and Installed by You extensions, and Couldn't Load. A card shows what
  the extension does, when it runs, how many downloads it has checked or
  **Needs setup**, and its switch, and opens the extension's page.
- **Activity** is what extensions found. Downloads a check is holding come
  first, with Review, which opens the download's Checks tab. Below is a table of
  every check on every download: status, download, extension, result and when.
  It sorts by any column and filters to problems or one extension, and a double
  click opens the download's Checks tab. The tab's name counts held downloads.
- **Develop** has the "Allow development extensions" switch, off by default,
  with whether `orb dev` is connected; the extensions loaded for development,
  with Reload and Show in Finder; the steps from `orb create` to an `.orbext`,
  each command with a copy button; and, beside them, what coding agents get and
  links to the developer docs.
- The toolbar has **Install Extension…**. Search looks through extensions, or
  checks on the Activity tab.

An extension's page opens with a back button. It has a header with the icon and
switch, then its settings with Verify, "How to Set It Up" (its `help.md`)
beside them, the downloads it checked most recently, what it runs and can do,
its logs, and an About section with the version, source, and Uninstall. The
tabs hide while it's open, and its Recent Checks has **Show All**, which opens
Activity filtered to it.

- **Official:** built by us and shipped inside OrbTorrent. They can be turned off
  but not removed.
- **Installed by You:** everything else, tagged **Not reviewed**, or
  **Development** while it's loaded from a folder by `orb dev`. Development
  extensions also get Reload and Show in Finder, and full error traces.
- **Runs** and **Can** are generated from the manifest, so they always match what
  OrbTorrent enforces.
- **⚠ Setup** means a required setting is empty. The extension's hooks are skipped
  until it's filled in, so a missing API key never holds up a download.

### Installing from a file

Installing an `.orbext` file or a folder always shows a sheet first: the
extension's name and author, "Not reviewed by OrbTorrent", and its Runs and Can
lists. Installing a newer version of an extension you already have shows the same
sheet, with any new permissions and hooks marked **New**.

A development extension doesn't ask again when you edit its manifest, since it's
your own code. OrbTorrent shows a notice instead.

### Checks on a download

The inspector gets a **Checks** tab, with one row per extension that ran on the
download:

```
✓  Fake Download Check   Passed                                  2s ago
⏳  VirusTotal Scan       Checking 3 of 10 files…
✗  VirusTotal Scan       12 of 70 engines flag setup.exe   Details  Report
```

- Each row can show the extension's details, a link, and **Run Again**.
- The possible results are Passed, Warning, Failed and Skipped (for example,
  "needs setup"). A run can also end as Didn't Finish: took too long, used too
  much memory, or crashed.
- A download that finished before an extension was turned on shows a **Run**
  button for it.
- A download's row in the list shows a small badge when a check failed or
  warned, or when the download is being held.

### Held downloads

When a check before the download starts fails:

- **With "Ask before downloading":** the checks run inside the confirmation as
  soon as the file list is known, and their results appear under the files. If
  one fails, the reason is shown and the Download button becomes **Download
  Anyway**.
- **With "Start downloading right away":** the download waits, stopped, as
  "Held by Fake Download Check". A notification says why, with **Show**,
  **Download Anyway** and **Remove**.

A **Warning** doesn't hold anything: the download starts and gets a badge.

A check that doesn't finish (too slow, crashed) doesn't hold the download
either. It starts, and the Checks tab shows the check didn't finish. A broken
extension must never stop your downloads.

## An extension

```
fake-download-check/
├── package.json        the manifest
├── src/
│   └── check.ts        one file per hook, named after it
├── tests/
│   └── disguised-program.json
├── assets/
│   └── icon.png
├── help.md             optional: setup steps, shown beside the settings
├── README.md
├── CHANGELOG.md
└── AGENTS.md           from the template, for coding agents
```

`orb build` writes `dist/`: the manifest, one bundled file per hook
(`hooks/check.js`), the assets and `help.md`. `orb package` zips `dist/` into an
`.orbext` file for installing on another Mac.

### The manifest

Like Raycast's, the manifest is `package.json` with extra fields:

```json
{
  "name": "virustotal",
  "title": "VirusTotal Scan",
  "description": "Checks finished downloads against about 70 antivirus engines.",
  "icon": "icon.png",
  "author": "orbtorrent",
  "license": "GPL-3.0-or-later",
  "hooks": [
    {
      "name": "scan",
      "title": "Scan with VirusTotal",
      "event": "afterFinish"
    }
  ],
  "permissions": {
    "files": "contents",
    "network": ["www.virustotal.com"]
  },
  "preferences": [
    {
      "name": "apiKey",
      "type": "password",
      "title": "API key",
      "description": "Your free VirusTotal API key.",
      "required": true
    },
    {
      "name": "scope",
      "type": "dropdown",
      "title": "Files to check",
      "required": false,
      "default": "risky",
      "data": [
        { "title": "Programs, archives and documents", "value": "risky" },
        { "title": "All files", "value": "all" }
      ]
    },
    {
      "name": "uploadUnknown",
      "type": "checkbox",
      "title": "Upload files VirusTotal hasn't seen",
      "label": "Uploaded files are shared with VirusTotal's customers",
      "required": false,
      "default": false
    }
  ],
  "verify": "verify",
  "dependencies": { "@orbtorrent/api": "^1.0.0" }
}
```

| Field | Required | Meaning |
|---|---|---|
| `name` | yes | Unique id: lowercase letters, digits and hyphens. |
| `title`, `description`, `icon`, `author` | yes | Shown on the Extensions page. The icon is a 512×512 PNG in `assets`. |
| `license` | no | Official extensions use the app's license. |
| `hooks` | yes | Each hook's `name` maps to `src/<name>.ts`. `event` is `beforeStart` or `afterFinish`. |
| `permissions.files` | no | `"contents"` lets the extension fingerprint and upload files. Names and sizes are always given. |
| `permissions.network` | no | Exact host names, reached over HTTPS only. |
| `preferences` | no | Settings OrbTorrent draws. Types: `textfield`, `password`, `checkbox`, `dropdown`. |
| `verify` | no | Maps to `src/<verify>.ts`, which checks the settings when the user presses Verify. |
| `dependencies["@orbtorrent/api"]` | yes | The API version it was built with. OrbTorrent refuses a newer major version and asks you to update the app. |

### Hooks

| | `beforeStart` | `afterFinish` |
|---|---|---|
| Runs | Once, when the file list is known and before any data downloads | Once, when every wanted file has finished |
| Can hold the download | Yes, by returning `failed` | No |
| Time limit | 15 s | 6 h, of which at most 2 min using the CPU |

A hook is the default export of its file:

```ts
import { Download, Result } from "@orbtorrent/api";

export default async function check(download: Download): Promise<Result> {
  const program = download.files.find((file) => /\.(mp4|mkv|avi)\.(exe|scr|lnk)$/i.test(file.path));
  if (program) {
    return { status: "failed", summary: `Contains a program disguised as a video: ${program.path}` };
  }
  return { status: "passed", summary: "Looks like a real release" };
}
```

```ts
interface Download {
  id: string; // the info hash
  name: string;
  size: number; // bytes of wanted files
  isPrivate: boolean;
  files: DownloadFile[];
}

interface DownloadFile {
  index: number;
  path: string; // relative to the download, never an absolute path
  size: number;
  wanted: boolean;
}

interface Result {
  status: "passed" | "warning" | "failed" | "skipped";
  summary: string; // one line, shown in the Checks tab
  details?: string; // markdown, shown under Details
  link?: { title: string; url: string };
}
```

Extensions never see a download's save folder, its trackers (they can carry a
private tracker's personal key), or anything about other downloads.

### The API

Everything an extension can do goes through `@orbtorrent/api`:

| API | What it does | Needs |
|---|---|---|
| `fetch(url, init)` | An HTTPS request. Returns `status`, `headers`, `text()` and `json()`. | The host in `permissions.network` |
| `files.sha256(file)` | The file's SHA-256 fingerprint, computed by OrbTorrent. | `"files": "contents"` |
| `files.formData(fields)` | A request body that includes a file, which OrbTorrent streams for the upload. | `"files": "contents"` and the host |
| `progress({ done, total, message })` | Updates the row in the Checks tab. | nothing |
| `storage.get / set / remove` | A small store for the extension (up to 1 MB). It survives restarts and updates and is deleted with the extension. | nothing |
| `getPreferenceValues<Preferences>()` | The extension's settings. Types are generated from the manifest into `orb-env.d.ts`. | nothing |
| `console.log / warn / error` | Logs: in the terminal during development, otherwise under Logs on the extension's page. Passwords are replaced with `•••`. | nothing |
| `setTimeout`, `clearTimeout`, promises, `async`/`await` | Standard JavaScript. | nothing |

There's no Node.js API (`fs`, `process`, `Buffer`, `require`) and no DOM.
`orb build` refuses code that imports them, with a message saying which API to
use instead.

A `verify` entry receives the settings and returns
`{ ok: true }` or `{ ok: false, message }`.

### Settings

- OrbTorrent draws each extension's settings on its page and checks
  that required ones are filled in.
- `password` values go in the macOS Keychain: service
  `com.orbtorrent.mac.extension.<name>`, one item per setting.
  Other values go in `~/Library/Application Support/OrbTorrent/Extensions/settings.json`.
- An extension receives only its own settings, when it runs. Removing an
  extension deletes them.
- An API key can only be sent to the hosts the extension declared, because every
  other request is refused.

## Runtime

### The experiment

On 28 September 2026 I built a throwaway helper program that runs JavaScriptCore
and a host that starts it, in the scratch folder, not in OrbTorrent. It was
signed the way OrbTorrent is (ad hoc, hardened runtime) and run both from the
terminal and from inside a signed app bundle opened normally. The results were
the same both ways.

| Test | Result |
|---|---|
| A hook with `async`/`await` and timers | ✓ |
| `fetch` to a declared host | ✓ Reached VirusTotal (401 without a key) |
| `fetch` to an undeclared host | Refused, with a message saying how to allow it |
| Fingerprint a 50 MB file through the host | 30 ms |
| Fingerprint without the permission | Refused |
| Endless loop | Killed after 2.08 s (limit 2 s) |
| Memory hog | Killed at 272–387 MB (limit 256 MB, checked every 20 ms) |
| Crash | Noticed (signal 6) |
| Thrown error | Reported with its message and stack |
| Helper reads a file on the Desktop | Denied |
| Helper lists `~/Downloads` | Denied |
| Helper writes to `/tmp` | Denied |
| Helper opens a network connection, looks up a host name, or uses URLSession | Denied |
| A program the helper starts reads a file on the Desktop | Denied: it inherits the sandbox |
| Start-up time | First ever 450 ms (macOS creates the sandbox folder), then 9–24 ms. Eight at once took 0.38 s. |
| Memory per helper | 5–11 MB |
| A compute benchmark | 2,256 ms without JIT, 43–56 ms with JIT |

For comparison, the same helper without the sandbox read the Desktop file,
listed Downloads, wrote to `/tmp` and reached the internet.

### The design that follows

- **A sandboxed helper per run.** `orb-extension-host` sits in `Contents/MacOS`,
  next to `qbittorrent-nox`. It's signed with the hardened runtime and two
  entitlements, `com.apple.security.app-sandbox` and
  `com.apple.security.cs.allow-jit`. It has its own bundle id,
  `com.orbtorrent.mac.extension-host`, in an embedded `Info.plist`.
- **A fresh helper for every hook run.** Nothing carries over between runs except
  through `storage`.
- **One message per line.** The host and the helper exchange JSON messages over
  stdin and stdout.
- **The helper can't do anything on its own.** Every request, fingerprint,
  upload and storage write is made by OrbTorrent after checking the manifest. Even
  an extension that found a bug in JavaScriptCore would still be inside the
  sandbox, with no files and no network.
- **JIT is on.** It's 40 times faster, and it's only enabled in the sandboxed
  helper, not in OrbTorrent itself.

Two routes I ruled out:

- `sandbox_init`, the old way for a program to sandbox itself, is marked "no
  longer supported", and its profiles are gone from the SDK.
- An XPC service runs as one shared process per app, so stopping one runaway
  extension would stop every running extension. Separate processes don't have
  that problem.

### Limits

| | `beforeStart` | `afterFinish` | `verify` |
|---|---|---|---|
| Time | 15 s | 6 h | 15 s |
| CPU time | 10 s | 2 min | 10 s |
| Memory | 512 MB | 512 MB | 512 MB |

- Time spent waiting for the network, for OrbTorrent or for a timer doesn't count
  as CPU time, so a VirusTotal scan pacing itself for rate limits isn't stopped.
- At most 4 helpers run at once, and one per extension per download.
- Memory is checked every 20 ms. A fast allocation can go over before it's caught
  (by up to 130 MB in the experiment), so the limit is a safety net, not an exact
  cap.
- A helper that goes over a limit is killed, and its check shows Didn't Finish
  with the reason.

### Network rules

- HTTPS only, to hosts listed exactly in `permissions.network`.
- Redirects are followed only to hosts on the same list.
- A host that resolves to a local or private address is refused. This uses the
  same rules as the tracker list.
- No cookies and no shared cache. The User-Agent is
  `OrbTorrent-Extension/<name>`.
- Responses are limited to 10 MB, and each request times out after 30 s.

### What OrbTorrent remembers

`~/Library/Application Support/OrbTorrent/Extensions/checks.json` holds, per
download and hook: the status, summary, details, link, start and finish times,
and the extension's version. It also holds which downloads are held or waiting
for checks. An entry is removed with its download.

After a restart:

- checks for held or waiting downloads run again;
- `afterFinish` runs that were interrupted run again.

Extensions use `storage` to avoid repeating work. For example, VirusTotal keeps
the fingerprints it has already looked up.

## When hooks run

### Before a download starts: one gate

Every way of adding a download goes through `AddTorrentCoordinator`. While at
least one `beforeStart` hook is on:

- **Ask before downloading:** the checks run inside the confirmation once the
  file list is known. For a magnet link that's when its lookup returns; for a
  `.torrent` file it's straight away.
- **Start right away:** the download is added with
  `stopCondition=MetadataReceived`. I checked this in qBittorrent 5.2.3's source:
  - A magnet link runs until its file list arrives. The engine then stops it,
    before any data is requested (`torrentimpl.cpp`, line 1866).
  - A `.torrent` file added with that condition starts out stopped
    (`sessionimpl.cpp`, line 2798).

  Either way, the checks then run and OrbTorrent starts the download or holds it.

While no `beforeStart` hook is on, adding works exactly as it does today.
Downloads already in the library aren't checked, because they've already
started.

### After a download finishes

- Each `afterFinish` hook that's on runs once when a download completes. That's
  the same moment the completion notification is sent (`CompletionNotifier`).
- At launch, OrbTorrent also runs hooks for downloads that completed after the
  extension was turned on (`completion_on` from the engine) and have no recorded
  run.
- Removing a download while its check runs stops the check.
- If the files were moved or deleted, the check reports Skipped: "files missing".

## Where extensions come from

| | Where it lives | Reviewed | Updates | Removable |
|---|---|---|---|---|
| Official | Inside OrbTorrent (`Contents/Resources/Extensions`), built from `extensions/` in this repo | Yes, here | With the app | No, only turned off |
| Installed by You | `~/Library/Application Support/OrbTorrent/Extensions/<name>` | No | By installing a newer file | Yes |
| Development | Your folder, while `orb dev` or `orb run` connects it | No | On every save | Yes |

- **Names are unique.** A file that uses an official extension's name is
  refused. The exception is a development copy, which stands in for the official
  extension while it's loaded, and its row reads "Development copy".
- **Development needs two things.** "Allow development extensions" must be on,
  and OrbTorrent asks the first time a folder connects. Without both, any program
  on the Mac could load code into OrbTorrent without your consent.

## Developer tools

### The package

`@orbtorrent/api` holds the types, the small runtime that talks to OrbTorrent,
the `orb` CLI and the templates. It lives in `sdk/` in this repo. Until it's
published to npm, templates install it from the repo.

### The CLI

| Command | What it does |
|---|---|
| `orb create <name> --template before-start\|after-finish` | Makes a new extension from a template, with `AGENTS.md`. |
| `orb build` | Type-checks, validates the manifest against its schema, bundles each hook into one file with esbuild, refuses Node.js imports and writes `dist/`. |
| `orb test [file]` | Runs the fixtures in `tests/` without OrbTorrent. |
| `orb dev` | Rebuilds on every save, loads the extension into the running OrbTorrent and streams its logs and results to the terminal. |
| `orb run <hook> --download <name or hash>` | Runs a hook on a real download in the running app and prints the result. |
| `orb lint` | ESLint with our rules. |
| `orb package` | Makes an `.orbext` file. |

- Every command takes `--json` for output a program can read.
- They exit with a non-zero code on failure.
- They never prompt when they aren't run in a terminal.

`orb dev` and `orb run` reach OrbTorrent through a socket at
`~/Library/Application Support/OrbTorrent/dev.sock`. Only your account can open
it, and it only works while development extensions are allowed.

### Tests

A test is a JSON file: a download, fake answers for the network, and what the hook
should return.

```json
{
  "name": "A program inside a film is held",
  "hook": "check",
  "download": {
    "name": "Dune.Part.Two.2024.1080p.WEB-DL",
    "files": [
      { "path": "Dune.Part.Two.2024.1080p.mp4.exe", "size": 2400000 },
      { "path": "README.txt", "size": 900 }
    ]
  },
  "expect": { "status": "failed", "summaryIncludes": "disguised" }
}
```

For a hook that uses the network or files, the test adds these fields:

- `preferences`;
- `files`, giving a fingerprint for each file;
- `mocks`, mapping each URL to its response (`status` and `json` or `text`).

Expectations can check:

- `status`;
- `summaryIncludes` and `summaryMatches`;
- `fetched`, the URLs requested;
- `not`, which inverts any of the others.

`orb test` runs the built hook in a Node `vm` context set up like the helper:
JavaScript built-ins and our API only, with no `require`, `process` or `Buffer`.
Node uses V8, not JavaScriptCore, so rare differences are possible. `orb run`
covers the real runtime.

## Agent support

- **`AGENTS.md` in every template.** It covers the commands, the API and its
  limits, the permission model, how to write tests, and the loop to follow:
  create, edit, `orb test`, `orb build`, then `orb run` on a real download. A
  one-line `CLAUDE.md` points Claude Code to it.
- **An Agent Skill.** `skills/build-orbtorrent-extension/SKILL.md` in this repo
  uses the open Agent Skills format, so it works in Claude Code, Codex, Cursor and
  others.
- **Docs as markdown.** They live in `docs/extensions/`, with generated `llms.txt`
  and `llms-full.txt`. They'll be put online with the website later.
- **Errors that say how to fix them.** For example:
  `Request to api.opensubtitles.com was refused. Add "api.opensubtitles.com" to permissions.network in package.json.`
- **`--json` everywhere**, and no prompts when there's no terminal.

## The official extensions

### Fake Download Check

A `beforeStart` hook, with no network access and no settings.

It first works out what a download is. A video, music or a book is what most
of its size is; otherwise its name decides, since a fake film often has no
video. A film or episode name has a resolution or episode marker (1080p,
S01E02, "Title - 28"), or a year with a source, codec or word such as "Full
Movie". A name with a version number (v2.3, 1.10.2) or words such as "for Mac",
"x64" or "FitGirl" is software. Software, games and courses carry programs for
good reason, so programs only count in videos, music and books.

**Held (failed):**

1. **A file with a double extension ending in a program or shortcut**, such as
   `Movie.mp4.exe`, `Episode.avi.lnk` or `Book.epub.exe`, or a Mac bundle such
   as `Sunset.jpg.app`, even with spaces or zero-width characters between the
   two; or a name with a right-to-left character. This rule applies to any
   download.
2. **A video, music or book download that contains a program:** a Windows
   program, script or shortcut (`.exe`, `.scr`, `.lnk`, `.msi`, `.bat`, `.js`,
   `.ps1`, `.jar` and the like), or a Mac one (`.app`, `.dmg`, `.pkg`,
   `.command`, `.scpt`, `.saver` and the like). Scripts don't count next to
   source code or in a course. Neither do RARBG's 99-byte
   `RARBG_DO_NOT_MIRROR.exe`, which is text, or the Java menus under `BDMV/` on
   a whole Blu-ray disc.
3. **A video download that's an archive plus a file about a password**, such as
   `password.txt`, `password.url` or `get-password.html`. That means the video is
   locked, and the password is sold or hidden elsewhere. A file named after the
   release, such as a scene `.nfo`, doesn't count.

**Warned:**

4. **The video is far too small:** under 150 MB for a 720p film, 300 MB for
   1080p, 1 GB for 2160p, or 100 MB for a film that claims no quality. Samples,
   trailers and extras don't count, and the rule doesn't apply to episodes,
   trailers or courses.
5. **A film from a year still to come.** A year more than five years ahead is
   taken as part of the title, as in *Blade Runner 2049*.
6. **The only video is `.wmv` or `.asf`.** That's the classic "codec required"
   fake.
7. **Link files** (`.url`, `.webloc`, `.html`) whose names say to download or
   watch elsewhere.
8. **A film-like name with no video file at all,** or with its video in an
   archive, except from a private tracker, where scene releases come that way.
9. **A course that includes a program,** since courses often include the
   software they teach.

**The summary says which file and why.** For example: "Contains a program
disguised as a video: Dune.Part.Two.2024.1080p.mp4.exe".

**Tests cover false positives too.** Each rule has a test, and so do real
downloads that must pass: film, TV and anime releases, scene releases in
archives, a whole Blu-ray disc and a DVD, Mac apps with "4K", "HDR" or
"Blu-ray" in their names, games, courses with their code, music, audiobooks,
comics and books. The app's tests run every one of them in OrbTorrent's own
extension host too.

### VirusTotal Scan

An `afterFinish` hook. It needs `"files": "contents"` and
`www.virustotal.com`. It's off until turned on, and shows ⚠ Setup until the key
is in.

**Settings:**

- API key (required);
- Files to check: "Programs, archives and documents" (the default) or "All files";
- Upload files VirusTotal hasn't seen (off by default).

`help.md` explains how to get a free key, and that it allows 4 lookups a minute
and 500 a day.

**Verify** looks up a known test file (EICAR) with the key:

- 200 means "✓ Key works";
- 401 means "VirusTotal didn't accept this key";
- 429 means the key works but its limit has been reached.

**Each run:**

1. Picks the files to check, the riskiest first: programs, then archives, then
   documents, then the rest.
2. For each file:
   - takes its fingerprint with `files.sha256`;
   - checks `storage` for an answer from the last 7 days;
   - otherwise asks `GET /api/v3/files/{sha256}`.
3. Waits 15 seconds between lookups. After a 429 it waits 60 seconds and tries
   again. If the daily limit runs out, it stops and reports Skipped: "Daily limit
   reached. Run again tomorrow."
4. Reports progress: "Checking 3 of 10 files…".
5. When uploading is on, it uploads unknown files up to 32 MB and waits for their
   analysis.

**The result:**

- **Failed** when 3 or more engines call a file malicious;
- **Warning** when 1 or 2 do, or any engine calls it suspicious;
- **Passed** otherwise.
- Files VirusTotal has never seen are listed in the details, not warned about,
  because new video releases are often unknown.
- The details list each flagged file, with a link to its VirusTotal report.

**Terms:** VirusTotal's free API "must not be used in commercial products or
services". OrbTorrent is free and each user brings their own key. If OrbTorrent
is ever sold, this needs another look.

## Repository layout

```
extensions/                         official extensions (source)
├── fake-download-check/
└── virustotal/
sdk/                                @orbtorrent/api: types, runtime, orb CLI
└── templates/                      before-start, after-finish
skills/build-orbtorrent-extension/  the Agent Skill
docs/extensions/                    developer docs, llms.txt
ExtensionHost/                      the sandboxed helper (a new target)
OrbTorrent/Extensions/              the app side: registry, runner, gate, Keychain
OrbTorrent/Views/Extensions/            the Extensions page and each extension's page
OrbTorrent/Views/Inspector/ChecksTabView.swift
```

**Building.**

- `make extensions` runs `orb build` for each official extension, and needs
  Node.js 22 or later.
- The app's build copies each `extensions/*/dist` into
  `Contents/Resources/Extensions`, and embeds and signs the helper.

**CI:**

- builds and tests every extension;
- on a pull request that changes an extension's permissions or hooks, posts the
  difference as a comment, for the reviewer to look at first.

## Build order

Each step is tested end to end against the real engine, the way the tracker work
was.

1. The helper target and the app's runner, from the experiment, with unit tests
   for the messages, limits and network rules.
2. The SDK, `orb build` and `orb test`, and the Fake Download Check with its
   tests.
3. The gate in `AddTorrentCoordinator`, held downloads and `checks.json`.
4. The Extensions page, the install sheet, the Checks tab, badges and
   notifications.
5. Settings, the Keychain and Verify; then VirusTotal, with the `afterFinish`
   trigger, progress and storage.
6. Installing from a file, the development socket, `orb dev` and `orb run`, and
   logs.
7. `AGENTS.md`, the Agent Skill, the docs, `llms.txt`, and the CI checks,
   including the permission difference.

## Decisions

All five were taken as recommended.

1. **Fake Download Check on by default.** Recommended: it's local, sends nothing
   anywhere, and asks before holding anything back for good.
2. **A `beforeStart` check that doesn't finish lets the download start.**
   Recommended, so a broken extension can't block downloads.
3. **VirusTotal's thresholds:** 3 or more engines means Failed, and 1 or 2 means
   Warning. Single-engine false alarms are common.
4. **Extension requests don't go through the VPN binding**, the same as the
   tracker list download. Changing that would need the app's own requests bound
   to the VPN interface.
5. **Official extensions use the app's license (GPL).** Other extensions can use
   any license.

## Still to check while building

- **Keychain prompts.** An ad-hoc signed app's Keychain access is tied to that
  exact build. So after each update, macOS may ask once to let OrbTorrent read
  its saved keys. With a Developer ID signature this goes away. If the prompt is
  a problem for unsigned releases, a fallback is needed.
- **JavaScript support.** Check which JavaScript features JavaScriptCore on
  macOS 26 supports. esbuild will target ES2022 to be safe.
- **`stopCondition` in practice.** Test it through OrbTorrent's add path with real
  magnet links and `.torrent` files.
- **The memory limit.** Measure how reliable it is with real extensions.

## What changed while building

- **After a download finishes, each extension's runs go one at a time.** That
  suits services with rate limits, like VirusTotal's 4 lookups a minute. At
  most 4 helpers run at once in all. Checks before a download starts aren't
  limited, as a download waits on them.
- **Downloads that finish between two refreshes still get their hooks.** A tiny
  download can finish before OrbTorrent ever sees it unfinished, so one that's
  new to the library and already finished counts too.
- **Remote `.torrent` links are fetched by OrbTorrent while checks are on**, so
  their files are known before they're added. Otherwise the engine fetches them,
  as before.
- **Tests run on a virtual clock**, and a mock can answer a set number of times
  (`times`), so a hook that waits out a rate limit is tested in moments.
- **Details are a subset of markdown:** paragraphs, `- ` lists, bold, code and
  links. There are no tables, which SwiftUI doesn't draw.
- **The Keychain prompt was confirmed.** A key that another program created
  (the test used `security add-generic-password`) makes macOS ask before
  OrbTorrent reads it. Keys entered in OrbTorrent's own settings don't prompt
  for the same build. After an ad-hoc signed update they may prompt once, until
  releases are signed with a Developer ID.
- **The development socket normalises folders.** `/private/tmp` and `/tmp` are
  the same folder, so it compares paths with symlinks resolved.
- **A download added stopped is checked too.** It fetches its file list, stops,
  is checked, and stays stopped as the user chose. It's held only if a check
  fails.
- **A helper's pending requests stop with it.** When OrbTorrent stops a helper
  (a limit, or the download being removed), requests it was waiting on, such as
  a VirusTotal lookup, are cancelled.
- **Extensions moved from Settings to the main window.** They're OrbTorrent's
  own feature, so they have a page in the sidebar instead of a Settings tab,
  with Installed, Activity and Develop tabs so no one page does every job.
  Opening an `.orbext` file from Finder opens that page with the install sheet,
  and the Checks tab's **Set Up** link opens the extension's page.
- **Extensions can all be turned off.** For someone who wants a plain torrent
  client, one switch on the Extensions page stops every hook and hides checks
  everywhere, keeping the sidebar row so the way back is always there.

