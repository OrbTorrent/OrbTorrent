---
title: Storage and progress
description: Keep data between runs with storage, show progress on long checks, read about the extension with environment, and wait without using CPU time.
---

## Keep data between runs

Every run of a hook is a fresh process, so nothing carries over by itself. `storage` keeps JSON values between runs:

```ts
import { storage } from "@orbtorrent/api";

const cached = await storage.get<{ malicious: number; at: number }>(sha256);
if (cached && Date.now() - cached.at < 7 * 24 * 60 * 60 * 1000) {
  // Use the answer from the last week, rather than asking again.
}
await storage.set(sha256, { malicious: 0, at: Date.now() });
```

| | |
|---|---|
| `storage.get(key)` | The value, or `undefined` if there's none. |
| `storage.set(key, value)` | Keeps any JSON value. |
| `storage.remove(key)` | Removes it. |
| `storage.keys()` | Every key, as an array. |

- **Up to 1 MB in all,** and keys up to 200 characters. Past the limit, `set` throws "Storage is full: an extension can keep up to 1 MB. Remove keys it no longer needs."
- **Kept across runs and updates,** and deleted when the extension is removed.
- **Each extension has its own.** No other extension can read it.

Use it to avoid repeating work, such as lookups you've already made. VirusTotal Scan keeps each answer for a week, so running it again doesn't use up the user's daily limit. Don't keep secrets here: they belong in a [password setting](/docs/extensions/settings).

## Show progress

On a long check, tell the user how far it's got. The check's row in the **Checks** tab shows it, and so does `orb dev`:

```ts
import { progress } from "@orbtorrent/api";

for (const [index, file] of checking.entries()) {
  await progress({ done: index, total: checking.length, message: `Checking ${file.path}…` });
  // …
}
```

`done` and `total` draw a progress bar, and `message`, up to 200 characters, says what's happening, such as "Waiting a minute for VirusTotal's rate limit…".

## Wait

`sleep(milliseconds)` waits without using CPU time, so it doesn't count towards a hook's CPU limit:

```ts
import { sleep } from "@orbtorrent/api";

await sleep(15_500); // 4 requests a minute
```

`setTimeout` works too, but `sleep` reads better in an `async` hook.

## About the extension

`environment` says how the extension is running:

| | |
|---|---|
| `environment.extensionName` | Its `name` from `package.json`. |
| `environment.isDevelopment` | Whether it's loaded from a folder with `orb dev` or `orb run`, rather than installed. |
| `environment.entryPoint` | What's running: `{ type: "hook", name, event }` or `{ type: "verify", name }`. |
| `environment.apiVersion` | The extension API version this OrbTorrent provides, such as `1.0.0`. |

## Logs

`console.log`, `info`, `debug`, `trace`, `warn` and `error` write to the extension's log. Users see it on the extension's page, under **Logs**, and `orb dev` and `orb run` print it as it happens. Each entry is cut at 10,000 characters, and OrbTorrent hides password settings in it. Don't log file contents, or anything private.
