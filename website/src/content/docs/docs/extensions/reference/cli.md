---
title: The orb command
description: Every orb command and option, what it needs, what it prints, and the JSON it prints with --json, for scripts and coding agents.
tableOfContents:
  maxHeadingLevel: 3
---

`orb` comes with `@orbtorrent/api`. It makes, tests, builds, runs and shares extensions. Run it from an extension's folder with `npx orb`, or through the `npm` scripts every new extension has.

```txt title="npx orb --help"
Usage: orb <command> [options]

Commands:
  create <name>        Make a new extension in a new folder
                         --template before-start|after-finish   (default before-start)
                         --title "<title>"
  build                Check package.json, type-check and bundle into dist/
  test [files…]        Run the tests in tests/, without OrbTorrent
  lint                 Check the code with ESLint (--fix to fix what it can)
  doctor               Check Node.js, OrbTorrent and this extension, and say what to fix
  dev                  Load into OrbTorrent, rebuild on every save and show logs
  downloads            List your downloads in OrbTorrent, to run a hook on
  run [hook]           Run a hook on one of your downloads in OrbTorrent
                         --download "<name or info hash>"
  install              Package it and ask OrbTorrent to install it, once you confirm
  package              Make <name>.orbext, to install on another Mac

Options:
  --json               Print results as JSON, for scripts and coding agents
  --help, --version
```

## For scripts and agents

- **`--json`** prints one JSON object, with `"ok"` saying whether the command succeeded.
- **Nothing prompts.** `orb install` waits for the user's answer in OrbTorrent, rather than in the terminal.
- **The exit status is 1 when something's wrong,** and 0 otherwise.
- **Errors say what to do.** With `--json`, a failed command prints `{ "ok": false, "error": "…", "details": ["…"] }`.

## Without OrbTorrent

These work anywhere Node.js 22.13 or later does, including CI.

### `orb create`

```sh
npx orb create <name> [--template before-start|after-finish] [--title "<title>"] [--dir <folder>]
```

Makes a new extension in a new folder. The name is its id: lowercase letters, digits and hyphens, such as `plex-mover`. The title, shown in OrbTorrent, comes from the name unless you give one.

Usually you'd run it through `npm create`, which uses the newest `@orbtorrent/api` from npm:

```sh
npm create @orbtorrent/extension@latest notify-me -- --template after-finish
```

The `--` passes the options on to `orb create`. Then `cd` into the folder and run `npm install`.

```json title="--json"
{ "ok": true, "folder": "/Users/you/Projects/notify-me" }
```

### `orb build`

```sh
npx orb build
```

Checks `package.json`, writes `orb-env.d.ts` with your settings' types, type-checks the code, and bundles each hook into `dist/`, the way OrbTorrent loads it:

```
dist/
├── package.json      the manifest, with the API version it was built with
├── hooks/check.js    one file per hook
├── verify.js         if there's a verify
├── assets/, help.md, README.md, CHANGELOG.md
```

It refuses Node.js modules, and says what to use instead. npm packages that are plain JavaScript are bundled in. It warns, rather than fails, about an icon that doesn't exist.

```json title="--json"
{ "ok": true, "name": "no-screensavers", "dist": "/Users/you/Projects/no-screensavers/dist", "hooks": ["check"], "warnings": [] }
```

### `orb test`

```sh
npx orb test [files…]
```

Builds, then runs every JSON test in `tests/`, or the files you name, without OrbTorrent. [Testing](/docs/extensions/testing) explains the format.

```json title="--json"
{
  "ok": true,
  "passed": 3,
  "failed": 0,
  "tests": [
    {
      "file": "tests/holds-a-screensaver.json",
      "name": "Holds a download with a screensaver in it",
      "passed": true,
      "failures": [],
      "result": { "status": "failed", "summary": "Contains a screensaver, which is a Windows program: Play Me.scr" },
      "logs": [],
      "fetched": []
    }
  ]
}
```

Each test has its `failures`, what the hook returned as `result`, or the `error` it threw, what it logged, and the requests it made.

### `orb lint`

```sh
npx orb lint [--fix]
```

Runs ESLint with OrbTorrent's rules: the recommended JavaScript and TypeScript rules, and errors for what doesn't exist where extensions run, such as `process`, `Buffer`, `require`, `window`, the global `fetch`, and Node.js modules. `--fix` fixes what it can. If the extension has its own `eslint.config.js`, that's used instead, and can build on OrbTorrent's with `@orbtorrent/api/eslint`.

```json title="--json"
{
  "ok": false,
  "errors": 1,
  "warnings": 0,
  "problems": [
    { "file": "src/check.ts", "line": 5, "column": 17, "severity": "error", "rule": "no-restricted-globals", "message": "Unexpected use of 'process'. process doesn't exist where extensions run. Use getPreferenceValues and environment from @orbtorrent/api." }
  ]
}
```

### `orb package`

```sh
npx orb package
```

Builds the extension and zips `dist/` into `<name>.orbext`, which anyone with OrbTorrent can install by opening it. It needs macOS.

```json title="--json"
{ "ok": true, "file": "/Users/you/Projects/no-screensavers/no-screensavers.orbext" }
```

## With OrbTorrent

These talk to OrbTorrent on the same Mac, which must be open with **Allow development extensions** on, on the **Develop** tab of its Extensions page. The first time a folder connects, OrbTorrent asks the user whether to load it.

### `orb doctor`

```sh
npx orb doctor
```

Checks everything the other commands need, and says what to fix, and who can fix it:

| Check | Looks at |
|---|---|
| `node` | Node.js is 22.13 or later. |
| `extension` | The folder is an extension, and which `@orbtorrent/api` it uses. |
| `built` | It's been built into `dist/`. |
| `app` | OrbTorrent is installed, open, and allows development extensions. |
| `api` | OrbTorrent supports the extension API this extension was built with. |
| `allowed` | The user has allowed this folder in OrbTorrent. |
| `installed` | Whether it's installed, loaded for development, on or off. |

```json title="--json"
{
  "ok": false,
  "checks": [
    { "name": "node", "ok": true, "message": "Node.js 24.11.1" },
    { "name": "app", "ok": false, "message": "OrbTorrent is open, but doesn't allow development extensions.", "fix": "Ask the user to turn on “Allow development extensions” in OrbTorrent: Extensions, at the bottom of the sidebar, then the Develop tab. Only the user can. …" }
  ]
}
```

A check's `ok` is `true` when it's fine, `false` when it needs fixing, and `null` for information. `fix` says how, including when only the user can do it. `orb doctor` exits with 1 when any check is `false`.

### `orb dev`

```sh
npx orb dev
```

Builds the extension, loads it into OrbTorrent, and rebuilds and reloads it on every save. It prints the extension's checks, progress and logs as they happen, on any download. Press Control-C to stop: the extension stays loaded in OrbTorrent. It doesn't take `--json`.

[Run and debug](/docs/extensions/debugging#work-with-orb-dev) shows what it prints.

### `orb downloads`

```sh
npx orb downloads
```

Lists the downloads in OrbTorrent, to run a hook on.

```json title="--json"
{
  "ok": true,
  "downloads": [
    { "id": "dd8255ecdc7ca55fb0bbf81323d87062db1f6d1c", "name": "Big Buck Bunny", "size": 276000000, "progress": 1, "finished": true }
  ]
}
```

### `orb run`

```sh
npx orb run [hook] --download "<name or info hash>"
```

Builds and loads the extension, runs a hook in OrbTorrent on one of your downloads, and prints what it logged and returned. The hook can be left out when there's only one. `--download` takes part of a name, or a whole info hash. An `afterFinish` hook needs a finished download, and an `afterChecks` hook one that's finished or held. It prints what the hook found about each file, too.

```json title="--json"
{
  "ok": true,
  "type": "result",
  "hook": "check",
  "download": { "id": "dd8255ecdc7ca55fb0bbf81323d87062db1f6d1c", "name": "Big Buck Bunny" },
  "outcome": "returned",
  "status": "passed",
  "summary": "No screensavers",
  "message": "No screensavers",
  "logs": []
}
```

`outcome` is `returned`, or `didNotFinish` when the hook threw or went over a limit, with the reason in `summary`. `ok` is false, and the exit status 1, when it didn't finish.

### `orb install`

```sh
npx orb install
```

Packages the extension and asks OrbTorrent to install it. OrbTorrent shows the install sheet, and installs it if the user confirms, replacing any copy loaded for development. While development extensions are allowed, `orb install` waits for the answer:

```json title="--json"
{ "ok": true, "installed": true, "file": "/Users/you/Projects/no-screensavers/no-screensavers.orbext", "app": "OrbTorrent" }
```

If the user cancels, it fails with "The user chose not to install it." Without development extensions allowed, it opens the file in OrbTorrent, which shows the same sheet, and returns straight away with `"installed": false`.

## The npm scripts

Every new extension's `package.json` has:

| Script | Runs |
|---|---|
| `npm run build` | `orb build` |
| `npm test` | `orb test` |
| `npm run lint` | `orb lint` |
| `npm run dev` | `orb dev` |
| `npm run package` | `orb package` |

## Environment variables

| Variable | |
|---|---|
| `ORB_APP=dev` | Talks to **OrbTorrent Dev**, the build used while working on OrbTorrent itself, instead of OrbTorrent. |
