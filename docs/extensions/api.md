# API

Import everything from `@orbtorrent/api`. Extensions run in OrbTorrent's
sandboxed extension host, not Node.js or a browser, so this is how they reach
anything outside themselves.

## The environment

Extensions have the JavaScript language (ES2023 and newer) and these web APIs:

- `console`;
- `setTimeout`, `setInterval` and `queueMicrotask`;
- `URL` and `URLSearchParams`;
- `TextEncoder` and `TextDecoder`, UTF-8 only;
- `atob` and `btoa`;
- `crypto.randomUUID()` and `crypto.getRandomValues()`;
- `structuredClone`.

There's no `fs`, `path`, `process`, `Buffer`, `require`, global `fetch` or DOM.
`orb build` refuses Node.js modules and says what to use instead.

## `fetch(url, init)`

An HTTPS request to a host listed in `permissions.network`.

```ts
const response = await fetch("https://www.virustotal.com/api/v3/files/" + sha256, {
  headers: { "x-apikey": apiKey },
});
if (response.ok) console.log(await response.json());
```

- **`init`:** `method` (GET, HEAD, POST, PUT, PATCH or DELETE), `headers`, and
  `body`: text (use `JSON.stringify` for JSON) or a form from `files.formData`.
- **The response:** `status`, `ok`, `url` (after redirects), `headers.get()`,
  `text()` and `json()`.
- **Limits:** HTTPS on port 443 only, and never an address on the Mac or its
  local network. Redirects are followed only to declared hosts. Responses are
  limited to 10 MB, and each request times out after 30 s.

## `files`

These need `"files": "contents"` in `permissions`, and only work after a
download finishes.

- **`files.sha256(file)`:** the file's SHA-256 fingerprint in lowercase hex.
  OrbTorrent computes it natively, so large files are quick and don't count
  towards CPU time.
- **`files.formData({ name: "text", file: download.files[0] })`:** a multipart
  form for `fetch`. OrbTorrent streams the file from disk.

## `progress({ done, total, message })`

Updates the check's row in the Checks tab, for example "Checking 3 of 10 files…".

## `storage`

`get(key)`, `set(key, value)`, `remove(key)` and `keys()`. They store JSON
values, up to 1 MB in all. It's kept across runs and updates, and deleted with
the extension. Use it to avoid repeating work, such as lookups you've already
made.

## `getPreferenceValues()`

The extension's settings, typed from `package.json` in the generated
`orb-env.d.ts`. Every setting has a value: what the user chose, or its default,
or else `""`, `false`, or a dropdown's first option.

## `environment`

`extensionName`, `isDevelopment`, `entryPoint` and `apiVersion`.

## `sleep(milliseconds)`

Waits without using CPU time.

## Types

`Download`, `DownloadFile`, `Result`, `Status`, `Hook`, `Verify`,
`VerifyResult`, `Response`, `RequestInit` and `FormBody`.
