---
title: Read and add files
description: Fingerprint and upload a finished download's files, and add files such as subtitles next to them with files.save.
---

Every hook gets the **names and sizes** of a download's files. To do more, an extension asks for it in `package.json`:

| `"files"` | Lets it | Users see |
|---|---|---|
| `"contents"` | Fingerprint and upload the download's files | "Read the contents of your downloads" |
| `"add"` | Add files, such as subtitles, next to them | "Add files, such as subtitles, next to your downloads" |
| `["contents", "add"]` | Both | Both |

```json title="package.json"
{
  "permissions": {
    "files": "contents"
  }
}
```

Users see what it asks for on the extension's page, and before they install it.

Files only exist once a download has finished, so only `afterFinish` hooks can use them, and `afterChecks` hooks once the download has finished. A `beforeStart` hook that asks gets an error: "File 0 isn't available: it isn't downloaded yet, or it isn't part of this download."

Extensions never read or write files directly, and never see where they're saved. They ask OrbTorrent, which does it for them, after checking the request.

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

## Add a file

`files.save(file, suffix, contents)` adds a file next to one of the download's, in the same folder, named after it with `suffix`. Players and media servers find subtitles and artwork named this way:

```ts title="src/subtitles.ts"
import { Download, Result, fetch, files } from "@orbtorrent/api";

export default async function subtitles(download: Download): Promise<Result> {
  const video = download.files.find((file) => file.wanted && /\.(mkv|mp4)$/i.test(file.path));
  if (!video) return { status: "skipped", summary: "No video in this download" };

  const response = await fetch("https://subtitles.example.com/find?name=" + encodeURIComponent(video.path));
  const saved = await files.save(video, ".en.srt", await response.text());
  return { status: "passed", summary: `Added English subtitles: ${saved.path}`, notify: true };
}
```

`Film (2024)/Film.2024.1080p.mkv` gets `Film (2024)/Film.2024.1080p.en.srt`. It needs `"files": "add"`, and returns the new file's `path`, relative to the download's folder like the paths in `download.files`, and its `size`.

- **The suffix** starts with `.`, `-`, `_` or a space, and ends with an extension, such as `.en.srt`, `.forced.srt`, `-poster.jpg` or `.nfo`. It can't hold a `/`, so the file always lands next to the one it's for.
- **The contents** are text, saved as UTF-8, or bytes as a `Uint8Array`, such as an image from [`response.bytes()`](/docs/extensions/network#the-response).
- **Only files that can't run.** Subtitles (`.srt` `.ass` `.ssa` `.vtt` `.sub` `.idx` `.sup` `.smi` `.lrc`), text (`.txt` `.nfo` `.md` `.json` `.xml` `.csv` `.cue`), images (`.jpg` `.jpeg` `.png` `.webp` `.gif` `.heic`) and checksums (`.sfv` `.md5` `.sha1` `.sha256`). Never a program, a script or an app.
- **It never replaces a file,** except one the same hook added to the same download before, such as when the user runs it again. If a file is already there, such as subtitles that came with the download, `files.save` throws "“Film.2024.1080p.en.srt” already exists. An extension can't replace a file it didn't add." Catch it, and say what was there.
- **Up to 10 MB a file,** and **200 files and 50 MB a run**.

OrbTorrent marks each file it adds as downloaded from the internet, as browsers do, and makes it readable, never runnable.

### What the user sees

The Checks tab lists the files a check added, with **Show in Finder**. They belong with the download: moving it takes them along, and removing it with its files removes them too. Removing only the download leaves them, like its own files.

Set `notify: true` in the result, as above, so the user hears about it without opening the Checks tab. [Results](/docs/extensions/results#notification) explains.

## Which files

- **Skip files the user didn't want.** They're in `download.files` with `wanted: false`, and they weren't downloaded, so asking for one throws "File 1 isn't available".
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

Files a hook adds aren't written anywhere in a test. `expect` checks them with `saved`, their paths, and `savedIncludes`, text in each. `download.alsoOnDisk` lists files already next to the download's, which `files.save` won't replace:

```json title="tests/skips-a-film-with-subtitles.json"
{
  "download": {
    "name": "Film (2024)",
    "files": [{ "path": "Film (2024)/Film.2024.1080p.mkv", "size": 4000000000 }],
    "alsoOnDisk": ["Film (2024)/Film.2024.1080p.en.srt"]
  },
  "expect": { "status": "skipped", "summaryIncludes": "already has" }
}
```

[Testing](/docs/extensions/testing) has the rest.
