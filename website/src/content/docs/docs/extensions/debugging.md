---
title: Run and debug
description: Load an extension into OrbTorrent while you work on it, run a hook on a real download, read its logs, and fix what orb doctor finds.
---

Tests catch most problems without OrbTorrent. To see an extension work for real, load it into OrbTorrent and run it on your downloads.

## Get OrbTorrent ready

`orb dev` and `orb run` talk to OrbTorrent on your Mac. They need:

1. **OrbTorrent open.**
2. **Allow development extensions** on: **Extensions**, at the bottom of OrbTorrent's sidebar, then the **Develop** tab. Only you can turn it on.
3. **Your folder allowed.** The first time a folder loads, OrbTorrent asks whether to load it. Allow it.

`npx orb doctor` checks all of this, and says what's missing:

```txt title="npx orb doctor"
✓ Node.js 24.11.1
✓ No Screensavers (no-screensavers), with @orbtorrent/api 1.0.3
✓ Built into dist/
✗ OrbTorrent is open, but doesn't allow development extensions.
  → Ask the user to turn on “Allow development extensions” in OrbTorrent: Extensions, at the bottom of the sidebar, then the Develop tab. Only the user can. If the switch at the top of the Installed tab is off, extensions are off altogether, and that needs turning on first.

1 thing to fix.
```

A ✓ is fine, a ✗ needs fixing, and a · is information. [orb doctor](/docs/extensions/reference/cli#orb-doctor) lists everything it checks.

## Work with orb dev

```sh
npm run dev
```

```txt title="Output"
✓ Loaded No Screensavers into OrbTorrent.
Rebuilding on every save. Press Control-C to stop; the extension stays in OrbTorrent.
```

`orb dev` loads the extension into OrbTorrent, then rebuilds and reloads it every time you save a file. It also prints what the extension does as it happens, on any download:

```txt title="Output"
[check · Ocean Life (2026) 1080p] ✗ failed: Contains a screensaver, which is a Windows program: Play Me.scr
✓ Rebuilt and reloaded 14:02:31
```

Each line says which hook and which download, then the check's result, its progress, or what it logged.

A loaded extension runs on new downloads like an installed one, and shows on the **Develop** tab under **In Development**, with **Reload** and **Show in Finder**. It stays loaded after you stop `orb dev`, until you remove it from its page or install it for good.

:::note[Developing an official extension]
A development copy of an official extension, such as the Fake Download Check, stands in for the official one while it's loaded, marked **Development copy**. Remove it from its page, and the official one takes its place again.
:::

## Run a hook on a download

To try a hook on one of your downloads, list them, then run it:

```sh
npx orb downloads
npx orb run check --download "Big Buck Bunny"
```

```txt title="npx orb downloads"
finished   276.0 MB  Big Buck Bunny  dd8255ecdc7ca55fb0bbf81323d87062db1f6d1c
42%          6.0 GB  ubuntu-26.04-desktop-amd64.iso  0d6a0b7f4b3e2e4a8b9c1d2e3f405162738495a6

Run a hook on one with `npx orb run <hook> --download "<name or info hash>"`. An afterFinish hook needs a finished one, and an afterChecks hook one that's finished or held.
```

- **`--download`** takes part of a download's name, or its whole info hash. If it matches more than one, `orb run` lists them, so you can be more specific.
- **The hook's name** can be left out when the extension has only one.
- **An `afterFinish` hook needs a finished download,** since it reads files that are all there. An `afterChecks` hook needs one that's finished or held by a check, and gets the checks' results as they are.
- **Run by hand, every file is new,** so `isNew` is `true` for each finished file.

`orb run` builds the extension, loads it, runs the hook inside OrbTorrent, and prints what it logged and returned:

```txt title="Output"
✓ passed: No screensavers
```

The result also shows in the download's **Checks** tab, as a real check would.

## Logs

Anything the extension writes with `console.log`, `console.warn`, `console.error` and the rest goes to its log:

- **In OrbTorrent,** on the extension's page, under **Logs**, with **Clear** and **Show Log File**. The file is `~/Library/Application Support/OrbTorrent/Extensions/Logs/<name>.log`.
- **In your terminal,** while `orb dev` or `orb run` is running.
- **In tests,** under a failing test's output, and in `orb test --json`'s `logs`.

When a hook throws, its stack trace goes in the log too. OrbTorrent hides password settings in logs.

## When a check didn't finish

The **Checks** tab says why, and so does `orb run`:

| It says | Because | Try |
|---|---|---|
| Didn't finish: *the error's message* | The hook threw. | Read the stack trace in its log. |
| Didn't finish: it took longer than 15 s | Over the time limit. | Fewer or faster requests before a download starts, or move the work to `afterFinish`. |
| Didn't finish: it kept the processor busy for over 10 s | Over the CPU limit. | Do less work in loops. Waiting with `sleep` doesn't count. |
| Didn't finish: it used more than 512 MB of memory | Over the memory limit. | Don't hold large responses or lists. |
| Didn't finish: It returned something that isn't a result | It returned no `status` or `summary`. | Return `{ status, summary }`. |

[Limits](/docs/extensions/reference/limits) has every limit, and [Errors and fixes](/docs/extensions/reference/errors) every error message.

## OrbTorrent Dev

If you build OrbTorrent itself, put `ORB_APP=dev` before `orb` commands to reach **OrbTorrent Dev** instead:

```sh
ORB_APP=dev npx orb run check --download "Big Buck Bunny"
```
