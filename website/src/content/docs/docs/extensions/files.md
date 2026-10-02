---
title: Reading files
description: Fingerprint a finished download's files with files.sha256, and upload them to a service with files.formData.
---

Every hook gets the **names and sizes** of a download's files. To use their **contents**, an extension asks for it:

```json title="package.json"
{
  "permissions": {
    "files": "contents"
  }
}
```

Users see this as "Read the contents of your downloads", on the extension's page and before they install it.

File contents only exist once a download has finished, so only `afterFinish` hooks can use them. A `beforeStart` hook that asks gets an error: "File 0 isn't available: it isn't downloaded yet, or it isn't part of this download."

Extensions never read files directly, and never see where they're saved. They ask OrbTorrent, which reads the file, for one of two things.

## Fingerprint a file

`files.sha256(file)` returns the file's SHA-256 fingerprint, in lowercase hex:

```ts title="src/scan.ts"
import { Download, Result, files } from "@orbtorrent/api";

export default async function scan(download: Download): Promise<Result> {
  for (const file of download.files.filter((file) => file.wanted)) {
    const sha256 = await files.sha256(file);
    // Look the fingerprint up with a service, such as VirusTotal.
  }
  return { status: "passed", summary: "…" };
}
```

OrbTorrent computes it natively, so even large files are quick, and the time doesn't count towards the hook's CPU limit. Pass a file from `download.files`, or its `index`.

## Upload a file

`files.formData(fields)` makes a multipart form to send with [`fetch`](/docs/extensions/network). Give it text fields, and files from `download.files`:

```ts
import { fetch, files } from "@orbtorrent/api";

const form = files.formData({ file: download.files[0] });
const response = await fetch("https://www.virustotal.com/api/v3/files", {
  method: "POST",
  headers: { "x-apikey": apiKey },
  body: form,
});
```

OrbTorrent streams the file from disk as it uploads, so the extension never holds it in memory.

To set a file's name or type in the form, build it with `append`:

```ts
const form = files.formData({ comment: "From OrbTorrent" });
form.append("file", download.files[2], { filename: "sample.bin", contentType: "application/octet-stream" });
```

:::caution[Uploading shares the file]
Uploading a user's file sends it to someone else. Only upload when the user has turned it on in your settings, say where it goes, and leave it off for anything private. VirusTotal Scan's upload setting is off unless the user turns it on.
:::

## Which files

- **Skip files the user didn't want.** They're in `download.files` with `wanted: false`, and they weren't downloaded.
- **Files can be missing.** If the user moved or deleted a file after it finished, asking for it throws "File 3 is missing: it was moved or deleted after downloading." Catch it, and report what you could check.
- **Check the riskiest first,** such as programs before videos, so a hook that's stopped early has checked what matters.

## Test it

In a test, give each file a `sha256`, which `files.sha256` returns:

```json
{
  "download": {
    "name": "Tool 2.0",
    "files": [{ "path": "Tool 2.0/setup.exe", "size": 5000000, "sha256": "aaaa…" }]
  }
}
```

[Testing](/docs/extensions/testing) has the rest.
