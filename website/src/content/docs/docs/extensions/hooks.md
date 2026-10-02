---
title: Hooks
description: When beforeStart and afterFinish hooks run, what they receive, how they hold a download, and the limits they run within.
---

A **hook** is a function OrbTorrent calls at a moment in a download's life. It's the default export of `src/<hook name>.ts`, and receives the download:

```ts title="src/check.ts"
import { Download, Result } from "@orbtorrent/api";

export default async function check(download: Download): Promise<Result> {
  return { status: "passed", summary: "Looks like a real release" };
}
```

Each hook is listed in `package.json`, with the moment it runs at:

```json title="package.json"
{
  "hooks": [
    { "name": "check", "title": "Check for signs of a fake", "event": "beforeStart" }
  ]
}
```

An extension can have several hooks, each in its own file, at either moment.

## The two moments

| | `beforeStart` | `afterFinish` |
|---|---|---|
| **Runs** | Once the file list is known, before any data downloads | Once every wanted file has finished |
| **Can hold the download** | Yes: `failed` holds it until the user decides | No, it reports |
| **File contents** | No: the files don't exist yet | Yes, with `"files": "contents"` |
| **Time limit** | 15 s, of which 10 s of CPU | 6 h, of which 2 min of CPU |
| **Memory** | 512 MB | 512 MB |

**Check as early as you can.** A download's names and sizes are known before it starts, so a check on them belongs in `beforeStart`, where it can save the user a download. Use `afterFinish` to read the files themselves, or to act once a download is done, such as sending a notification.

## Before a download starts

Every way of adding a download goes through the same gate:

- **When OrbTorrent asks before downloading,** the checks run in the confirmation as soon as the file list is known. A failed check turns the **Download** button into **Download Anyway**.
- **When downloads start right away,** OrbTorrent adds the download so that the engine stops it the moment its file list arrives. The checks run, then OrbTorrent starts it, or holds it and sends a notification with **Download Anyway** and **Remove**.
- **When the user adds a download stopped,** it fetches its file list, stops, and is checked the same way. It stays stopped as the user chose, and is held only if a check fails.

Every extension's `beforeStart` hooks run together, at the same time, so one slow check doesn't hold up the others. A download is held if any of them fails.

A hook that doesn't finish, because it threw, crashed or went over a limit, **lets the download start**. A broken extension never blocks downloads.

## After a download finishes

`afterFinish` hooks run once per download, when every file the user wanted has finished.

- **Each extension's runs go one at a time,** which suits services with rate limits. A hook for ten finished downloads checks them one after another.
- **At launch,** OrbTorrent also runs them for downloads that finished while it wasn't running, if that was after the extension was turned on.
- **A failed or warning result sends a notification,** so the user sees it without opening the window.

## Running again

The user can run any hook again from a download's **Checks** tab, or from the **Activity** tab. If a held download passes when its `beforeStart` checks run again, it starts.

While you're developing, `npx orb run <hook> --download "<name>"` runs a hook on one of your downloads. [Run and debug](/docs/extensions/debugging) explains.

## What a hook receives

```ts
interface Download {
  id: string;          // its info hash
  name: string;
  size: number;        // bytes of the wanted files
  isPrivate: boolean;  // from a private tracker
  files: DownloadFile[];
}

interface DownloadFile {
  index: number;
  path: string;        // relative to the download's folder, including its top folder
  size: number;        // bytes
  wanted: boolean;     // whether the user chose to download it
}
```

- **Paths are relative,** such as `Big Buck Bunny/Big Buck Bunny.mp4`. Hooks never see where a download is saved.
- **Files the user skipped are listed,** with `wanted: false`. Most checks should leave them out, since they won't arrive.
- **Hooks never see a download's trackers,** which can carry a private tracker's personal key, or any other download.

To read a file's contents, an `afterFinish` hook asks for `"files": "contents"` in its permissions and uses [`files`](/docs/extensions/files).

## What a hook returns

A [result](/docs/extensions/results): a status, a one-line summary, and optionally details in Markdown and a link.

```ts
return {
  status: "failed",
  summary: "Contains a program disguised as a video: Film.mp4.exe",
  details: "A film never needs a program. `.exe` files run on Windows.",
  link: { title: "Read more", url: "https://example.com/fakes" },
};
```

## Each run is fresh

Every run of a hook starts a new, sandboxed process, which exits when the hook returns. Nothing carries over from one run to the next, except what you keep in [`storage`](/docs/extensions/storage). Module-level variables start again each time.

## When hooks don't run

- **The extension is off,** on the Extensions page, or extensions are off altogether.
- **A required setting is empty.** The extension shows **Needs setup**, and its hooks are skipped until it's filled in. [Settings](/docs/extensions/settings) explains.
- **It needs a newer OrbTorrent.** An extension built with a newer API than OrbTorrent supports doesn't run. [Versions](/docs/extensions/reference/api#versions) explains.

Turning extensions off stops any checks running. A download waiting on its checks starts, and one that's held stays paused for the user to start.
