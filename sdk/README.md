# @orbtorrent/api

Build extensions for [OrbTorrent](https://orbtorrent.com), the BitTorrent app
for macOS. This package is the API extensions use, and `orb`, the
command-line tool that makes, tests, builds and shares them.

An extension hooks into a moment in a download's life, like a check on a pull
request: it can look at a download **before it starts** and hold it until the
user decides, or act on it **after it finishes**. Its result shows in the
download's Checks tab. OrbTorrent's own Fake Download Check and VirusTotal Scan
are extensions built with this package.

## Make one

You need Node.js 22.13 or later, and OrbTorrent to load it into.

```sh
npm create @orbtorrent/extension size-guard
cd size-guard
npm install
```

There are two templates. `before-start`, the default, holds downloads bigger
than a size you choose. `after-finish` sends a notification to your phone when
a download finishes; choose it with `-- --template after-finish`.

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
npm test                               # orb test: runs tests/*.json without OrbTorrent
npm run build                          # orb build: validates, type-checks and bundles into dist/
npm run lint                           # orb lint: ESLint with OrbTorrent's rules
npm run dev                            # orb dev: loads it into OrbTorrent, rebuilds on every save
npx orb run check --download "Name"    # runs a hook on one of your downloads
npx orb package                        # makes size-guard.orbext, to install on any Mac
```

`orb dev` and `orb run` need OrbTorrent open with **Allow development
extensions** on, on the Develop tab of its Extensions page. Every command takes
`--json` for output a script or coding agent can read, never prompts, and exits
with 1 when something's wrong.

## A hook

```ts
import { Download, Result } from "@orbtorrent/api";

export default async function check(download: Download): Promise<Result> {
  const program = download.files.find((file) => file.path.endsWith(".exe"));
  if (program) {
    return { status: "failed", summary: `Contains a Windows program: ${program.path}` };
  }
  return { status: "passed", summary: "No programs" };
}
```

A hook returns `passed`, `warning`, `failed` or `skipped`, with a one-line
summary and optional details in Markdown. Before a download starts, `failed`
holds it. A hook that throws or runs out of time shows "Didn't finish", and a
download is never blocked by a broken extension.

| | `beforeStart` | `afterFinish` |
|---|---|---|
| Runs | Once the file list is known, before any data downloads | Once every wanted file has finished |
| Can hold the download | Yes | No, it reports |
| File contents | Not yet | Yes, with `"files": "contents"` |
| Time limit | 15 s | 6 h (2 min of CPU) |

## What an extension can use

Extensions run in OrbTorrent's sandboxed extension host (JavaScriptCore), not
Node.js or a browser. Besides the JavaScript language, timers, `URL`, text
encoding and `crypto.randomUUID()`, everything goes through this package, and
OrbTorrent checks each call against the permissions in `package.json`:

```ts
fetch(url, { method?, headers?, body? })   // HTTPS to the hosts in permissions.network
files.sha256(file)                          // a finished file's fingerprint
files.formData({ field: "text", file })     // upload a file with fetch
progress({ done?, total?, message? })       // shown in the Checks tab
storage.get / set / remove / keys           // JSON, up to 1 MB, kept across runs
getPreferenceValues()                       // the extension's settings, typed
environment                                 // name, development or not, API version
sleep(milliseconds)
```

Settings (text fields, passwords kept in the Keychain, checkboxes and menus)
are declared in `package.json`, and OrbTorrent draws them. Users see what an
extension can do, from its hooks and permissions, before they install it.

## Versions

OrbTorrent runs extensions built with this package's major version, up to the
minor version it supports. An extension built with 1.2 needs an OrbTorrent that
supports 1.2; OrbTorrent says so if it's too old. New things come in minor
versions, and anything that would break an extension waits for a new major
version. See the [changelog](CHANGELOG.md).

## Docs

- [The extension docs](https://github.com/sanjevirau/OrbTorrent/tree/main/docs/extensions):
  hooks, the API, the manifest, tests, sharing and security.
- `AGENTS.md`, in every new extension: the whole API, the rules and the loop in
  one file, for coding agents. There's also an
  [Agent Skill](https://github.com/sanjevirau/OrbTorrent/tree/main/skills/build-orbtorrent-extension)
  and [llms.txt](https://github.com/sanjevirau/OrbTorrent/blob/main/docs/extensions/llms.txt).
- Problems: [issues](https://github.com/sanjevirau/OrbTorrent/issues), or
  help@orbtorrent.com.

## Licence

MIT, so your extension can use any licence you like. OrbTorrent itself is
GPL-3.0-or-later.
