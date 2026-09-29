# Hooks

A hook is the default export of `src/<hook name>.ts`. It receives the download
and returns a result.

```ts
import { Download, Result } from "@orbtorrent/api";

export default async function check(download: Download): Promise<Result> {
  return { status: "passed", summary: "Looks like a real release" };
}
```

## When they run

| | `beforeStart` | `afterFinish` |
|---|---|---|
| Runs | Once the file list is known, before any data downloads | Once every wanted file has finished |
| Can hold the download | Yes: `failed` holds it until the user decides | No, it reports |
| File contents | No: the files don't exist yet | Yes, with `"files": "contents"` |
| Time limit | 15 s, of which 10 s of CPU | 6 h, of which 2 min of CPU |
| Memory | 512 MB | 512 MB |

**Before a download starts**, every way of adding one goes through the same gate:

- **When OrbTorrent asks before downloading:** the checks run in the
  confirmation once the file list is known, and a failed check turns the
  Download button into Download Anyway.
- **When downloads start right away:** the download is added so that the engine
  stops it the moment its file list arrives. The checks run, then OrbTorrent
  starts it, or holds it and sends a notification with **Download Anyway** and
  **Remove**.
- **When the user adds a download stopped** before its file list is known, it
  fetches its file list, stops, and is checked the same way. It stays stopped
  as the user chose, and is held only if a check fails.

**After a download finishes**, hooks run once per download. Each extension's
runs go one at a time, which suits services with rate limits. At launch,
OrbTorrent also runs them for downloads that finished while it wasn't watching,
if that was after the extension was turned on. The user can run any hook again
from the Checks tab.

## What a hook receives

```ts
interface Download {
  id: string;        // the info hash
  name: string;
  size: number;      // bytes of the wanted files
  isPrivate: boolean;
  files: { index: number; path: string; size: number; wanted: boolean }[];
}
```

`path` is relative to the download's folder, including its top folder. Hooks
never see absolute paths, trackers (which can carry a private tracker's personal
key) or other downloads.

## What it returns

```ts
interface Result {
  status: "passed" | "warning" | "failed" | "skipped";
  summary: string;   // one line in the Checks tab
  details?: string;  // markdown: paragraphs, "- " lists, **bold**, `code`, [links](https://…)
  link?: { title: string; url: string };
}
```

- **`passed`:** nothing wrong.
- **`warning`:** worth a look. The download carries on and gets a badge.
- **`failed`:** something is wrong.
  - Before it starts, this holds the download.
  - After it finishes, it sends a notification.
- **`skipped`:** the check didn't apply or couldn't run.

A hook that throws, crashes, or goes over a limit shows **Didn't finish** with
the reason. A `beforeStart` hook that doesn't finish lets the download start: a
broken extension never blocks downloads.

## Writing good results

- **Say which file and why.** For example: "Contains a program disguised as a
  video: Film.mp4.exe".
- **Use `failed` only when you're sure.** A false alarm that holds a download
  is worse than a missed warning.
- **Before a download starts, a network error means `skipped`**, not `failed`.
