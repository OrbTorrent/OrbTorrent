---
title: API reference
description: Everything @orbtorrent/api provides, with each function's signature, types, limits and errors, and the JavaScript environment extensions run in.
tableOfContents:
  maxHeadingLevel: 3
---

Import everything from `@orbtorrent/api`:

```ts
import { fetch, files, getPreferenceValues, progress, sleep, storage, type Download, type Result } from "@orbtorrent/api";
```

Extensions run in OrbTorrent's sandboxed extension host, with JavaScriptCore, not Node.js or a browser. They have no file system or network of their own: everything outside the JavaScript language goes through these functions, which OrbTorrent checks against the permissions in `package.json`.

The functions only work inside OrbTorrent, or in `orb test`. Called anywhere else, they throw "@orbtorrent/api only works inside OrbTorrent, or in `orb test`."

## Hooks

### `Hook`

```ts
type Hook = (download: Download) => Result | Promise<Result>;
```

A hook is the default export of `src/<hook name>.ts`. [Hooks](/docs/extensions/hooks) explains when each kind runs.

### `HookEvent`

```ts
type HookEvent = "beforeStart" | "afterFinish" | "afterChecks";
```

When a hook runs, as its `event` in `package.json` says. `afterChecks` since 1.2.

### `Download`

```ts
interface Download {
  /** Its info hash. */
  id: string;
  name: string;
  /** Bytes of the wanted files. */
  size: number;
  /** Whether it's from a private tracker. */
  isPrivate: boolean;
  files: DownloadFile[];
  /** For an `afterChecks` hook: what the other extensions' checks found, worst first. */
  checks?: CheckResult[];
  /** For an `afterChecks` hook: whether a check is holding it before it starts. Otherwise it's finished. */
  isHeld?: boolean;
}
```

The download a hook runs on. `checks` and `isHeld` since 1.2.

### `DownloadFile`

```ts
interface DownloadFile {
  index: number;
  /** Relative to the download's folder, including its top folder. Never an absolute path. */
  path: string;
  /** In bytes. */
  size: number;
  /** Whether the user chose to download it. */
  wanted: boolean;
  /**
   * Once the download has finished: whether this file finished since the hook
   * last ran on it, such as one the user chose to download later. Every file
   * is new the first time, and when the user runs the hook again.
   */
  isNew?: boolean;
}
```

`isNew` since 1.2.

### `Result`

```ts
interface Result {
  status: Status;
  /** One line, shown in the list. Say which file and why. */
  summary: string;
  /** Markdown, shown under Details. */
  details?: string;
  link?: { title: string; url: string };
  /**
   * Also shows the summary as a notification, such as "Added English
   * subtitles". A warning or failure after a download finishes, and a
   * download held before it starts, are notifications already.
   */
  notify?: boolean;
  /**
   * What it found about particular files. OrbTorrent marks each problem
   * beside its file, and the result counts as no better than its worst file.
   * Each result replaces the hook's last one, so name every file you know
   * about, not only the new ones.
   */
  files?: FileResult[];
}
```

What a hook returns. [Results](/docs/extensions/results) explains how each part shows. `files` since 1.2.

### `FileResult`

```ts
interface FileResult {
  /** A file from `download.files`, or its index. */
  file: DownloadFile | number;
  status: "passed" | "warning" | "failed";
  /** Why, in a few words, such as "5 of 70 engines call it malicious". */
  summary?: string;
  link?: { title: string; url: string };
}
```

What a hook found about one of the download's files. Since 1.2.

### `CheckResult`

```ts
interface CheckResult {
  extension: { name: string; title: string };
  /** The hook's name. */
  hook: string;
  event: "beforeStart" | "afterFinish";
  /** `didNotFinish` when it threw, crashed or went over a limit. */
  status: Status | "didNotFinish";
  summary: string;
  details?: string;
  link?: { title: string; url: string };
  /** What it found about particular files, problems first. */
  files?: { index: number; path: string; status: "passed" | "warning" | "failed"; summary?: string; link?: { title: string; url: string } }[];
}
```

Another extension's result on the download, as an `afterChecks` hook sees it in `download.checks`. Results still running aren't included. Since 1.2.

### `Status`

```ts
type Status = "passed" | "warning" | "failed" | "skipped";
```

- `passed`: nothing wrong.
- `warning`: worth a look; the download carries on.
- `failed`: something's wrong. Before a download starts, this holds it until the user decides.
- `skipped`: the check didn't apply, or couldn't run.

## Settings

### `getPreferenceValues`

```ts
function getPreferenceValues<T = OrbPreferences>(): T;
```

The extension's settings, as the user set them, with defaults filled in. Every setting has a value: what the user chose, or its default, or else `""`, `false`, or a dropdown's first option.

### `OrbPreferences`

```ts
declare global {
  interface OrbPreferences {}
}
```

The type of the extension's settings. `orb build` fills it in from `package.json`, in `orb-env.d.ts`, so `getPreferenceValues()` knows each setting's name and type. [Settings](/docs/extensions/settings#read-them) shows an example.

### `Verify`

```ts
type Verify = (preferences: OrbPreferences) => VerifyResult | Promise<VerifyResult>;
```

The default export of the file `verify` names in `package.json`. It checks the settings when the user presses **Verify**.

### `VerifyResult`

```ts
type VerifyResult = { ok: true; message?: string } | { ok: false; message: string };
```

What `verify` returns. The message shows under the settings.

## Network

### `fetch`

```ts
function fetch(url: string | URL, init?: RequestInit): Promise<Response>;
```

An HTTPS request to a host listed in `permissions.network`. It throws if the request is refused, or fails.

- HTTPS on port 443 only, and never an address on the Mac or its local network. OrbTorrent connects to the very address it checked.
- Redirects are followed only to listed hosts. Otherwise the redirect itself is returned.
- Responses are limited to 10 MB, and each request to 30 seconds.
- There's no global `fetch`: import this one.

[Network requests](/docs/extensions/network) has examples.

### `RequestInit`

```ts
interface RequestInit {
  method?: "GET" | "HEAD" | "POST" | "PUT" | "PATCH" | "DELETE";
  headers?: Record<string, string>;
  /** Text (use `JSON.stringify` for JSON), or a form from `files.formData`. */
  body?: string | FormBody;
}
```

### `Response`

```ts
interface Response {
  readonly status: number;
  /** Whether the status is 200–299. */
  readonly ok: boolean;
  /** The address it came from, after any redirects. */
  readonly url: string;
  readonly headers: Headers;
  text(): Promise<string>;
  json<T = any>(): Promise<T>;
  /** The body's bytes, such as an image or a zip file. */
  bytes(): Promise<Uint8Array>;
  arrayBuffer(): Promise<ArrayBuffer>;
}
```

`text()` and `json()` read the body as UTF-8, and `bytes()` and `arrayBuffer()` as it came. Since 1.1.

### `Headers`

```ts
interface Headers {
  get(name: string): string | null;
  has(name: string): boolean;
  entries(): [string, string][];
}
```

A response's headers. Names are case-insensitive, and `entries()` gives them in lowercase.

## Files

### `files`

```ts
const files: {
  sha256(file: DownloadFile | number): Promise<string>;
  formData(fields: Record<string, string | DownloadFile>): FormBody;
  save(file: DownloadFile | number, suffix: string, contents: string | Uint8Array | ArrayBuffer): Promise<SavedFile>;
};
```

The download's files, only once it's finished: in `afterFinish` hooks, and in `afterChecks` hooks when it isn't held. Reading them needs `"files": "contents"` in `permissions`, and adding files next to them needs `"files": "add"`, or `["contents", "add"]` for both. Pass a file from `download.files`, or its `index`.

- **`files.sha256(file)`**: the file's SHA-256 fingerprint in lowercase hex, computed by OrbTorrent. Large files are quick, and the time doesn't count towards CPU time. OrbTorrent remembers it while the file stays as it was, so asking again, such as once more of the download has finished, doesn't read it again.
- **`files.formData(fields)`**: a multipart form to upload with `fetch`. OrbTorrent streams each file from disk.
- **`files.save(file, suffix, contents)`**: adds a file next to `file`, named after it: `files.save(video, ".en.srt", text)` saves `Film.2024.en.srt` beside `Film.2024.mkv`. The suffix starts with `.`, `-`, `_` or a space, and ends with an extension. Only subtitles, text, images and checksums, up to 10 MB each and 50 MB a run. It never replaces a file, except one the same hook added to the same download before, and throws if one's there. Text is saved as UTF-8. Since 1.1.

[Read and add files](/docs/extensions/files) has examples.

### `SavedFile`

```ts
interface SavedFile {
  /** Relative to the download's folder, like a `DownloadFile`'s path. */
  path: string;
  /** In bytes. */
  size: number;
}
```

A file `files.save` added.

### `FormBody`

```ts
class FormBody {
  readonly parts: FormPart[];
  append(name: string, value: string | DownloadFile, options?: { filename?: string; contentType?: string }): this;
}
```

A multipart form, which can include the download's files. Make one with `files.formData`, and add to it with `append`.

### `FormPart`

```ts
type FormPart =
  | { name: string; value: string }
  | { name: string; file: number; filename?: string; contentType?: string };
```

One field of a `FormBody`: text, or a file by its index.

## Progress and storage

### `progress`

```ts
function progress(update: { done?: number; total?: number; message?: string }): Promise<void>;
```

Shows how far along the check is, in the Checks tab and in `orb dev`, such as "Checking 3 of 10 files…". The message is cut at 200 characters.

### `storage`

```ts
const storage: {
  get<T = unknown>(key: string): Promise<T | undefined>;
  set(key: string, value: unknown): Promise<void>;
  remove(key: string): Promise<void>;
  keys(): Promise<string[]>;
};
```

JSON values the extension keeps between runs, up to 1 MB in all, with keys up to 200 characters. Kept across runs and updates, and deleted with the extension. [Storage and progress](/docs/extensions/storage) has examples.

### `sleep`

```ts
function sleep(milliseconds: number): Promise<void>;
```

Waits, without using CPU time.

### `environment`

```ts
const environment: {
  /** The extension's `name` from package.json. */
  readonly extensionName: string;
  /** Whether it's loaded from a folder with `orb dev`, rather than installed. */
  readonly isDevelopment: boolean;
  /** The hook or `verify` function running now. */
  readonly entryPoint: { type: "hook" | "verify"; name: string; event?: HookEvent };
  /** The API version this OrbTorrent provides, such as "1.2.0". */
  readonly apiVersion: string;
};
```

About the extension, and how it's running.

## The environment

Besides the JavaScript language itself, ES2023 and newer, extensions have:

| | |
|---|---|
| `console` | `log`, `info`, `debug`, `trace`, `warn` and `error`, to the extension's log. |
| Timers | `setTimeout`, `setInterval`, `clearTimeout`, `clearInterval` and `queueMicrotask`. |
| `URL` and `URLSearchParams` | Including `URL.canParse`. |
| `TextEncoder` and `TextDecoder` | UTF-8 only. |
| `atob` and `btoa` | Base64. |
| `crypto` | `randomUUID()` and `getRandomValues()`. |
| `structuredClone` | |

**Not available:** `fs`, `path`, `process`, `Buffer`, `require`, the global `fetch`, `window`, the DOM, and npm packages that need them. `orb build` refuses Node.js modules and says what to use instead, and `orb lint` flags the globals. npm packages that are plain JavaScript work: `orb build` bundles them in.

## Versions

`@orbtorrent/api`'s major and minor version are the extension API's. OrbTorrent runs extensions built with its own major version, up to the minor version it supports: one built with 1.2 needs an OrbTorrent that supports 1.2, and OrbTorrent says so if it's too old, rather than run it.

- **Patch versions,** such as 1.0.3, improve `orb` and fix bugs without changing the API.
- **Minor versions,** such as 1.1, add to the API.
- **Major versions,** such as 2.0, are for anything that would break an extension.

`npx orb doctor` says which API the OrbTorrent on your Mac supports. The [changelog](/docs/extensions/reference/changelog) lists every version.
