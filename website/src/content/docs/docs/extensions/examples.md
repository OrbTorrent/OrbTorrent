---
title: Examples
description: The templates and official extensions to learn from, a worked example that adds subtitles, and ideas for extensions to build.
---

## The templates

`npm create @orbtorrent/extension@latest` makes an extension from one of two templates, each complete with tests:

| Template | What it does | Shows how to |
|---|---|---|
| `before-start`, the default | Holds downloads bigger than a size you choose. | Hold a download, and use a dropdown setting. |
| `after-finish` | Sends a notification to your phone through [ntfy](https://ntfy.sh) when a download finishes. | Call a web service, use a required setting, and check it with `verify`. |

```sh
npm create @orbtorrent/extension@latest notify-me -- --template after-finish
```

The after-finish template's hook, in full:

```ts title="src/notify.ts"
import { Download, Result, fetch, getPreferenceValues } from "@orbtorrent/api";

/** Runs once, when every wanted file of a download has finished. */
export default async function notify(download: Download): Promise<Result> {
  const { topic } = getPreferenceValues();
  // Only hosts listed in permissions.network can be reached.
  const response = await fetch(`https://ntfy.sh/${encodeURIComponent(topic)}`, {
    method: "POST",
    headers: { Title: "Download finished" },
    body: download.name,
  });
  if (!response.ok) {
    return { status: "skipped", summary: `ntfy didn't take the message (status ${response.status})` };
  }
  return { status: "passed", summary: `Sent to your ntfy topic “${topic}”` };
}
```

## The official extensions

Both are open source, in the [`extensions/`](https://github.com/sanjevirau/OrbTorrent/tree/main/extensions) folder, and built with the same SDK and tools as yours.

### Fake Download Check

[Source](https://github.com/sanjevirau/OrbTorrent/tree/main/extensions/fake-download-check) · `beforeStart` · no permissions

Holds downloads that look fake, such as a film that contains a program, using only the names and sizes of their files. Worth reading for:

- working out what a download is, a film, an album, a book or software, from its files and name;
- telling `failed` from `warning` carefully, so it holds only what's almost certainly fake;
- a test for each rule, and tests of real releases that must pass.

### VirusTotal Scan

[Source](https://github.com/sanjevirau/OrbTorrent/tree/main/extensions/virustotal) · `afterFinish` · `"files": "contents"`, `www.virustotal.com`

Looks up each finished file's fingerprint on VirusTotal. Worth reading for:

- pacing requests for a rate limit with `sleep`, and backing off on 429;
- keeping answers in `storage`, so running again doesn't use up the user's daily limit;
- checking the riskiest files first, and showing `progress`;
- a `password` setting checked with `verify`, and an opt-in upload with `files.formData`;
- tests that mock every answer VirusTotal gives, including its limits.

## A worked example: subtitles

Someone's first idea for an extension was to fetch the right subtitles once a film finishes. A coding agent built it in about ten minutes, and this is a shorter version of it. It finds subtitles in your language on [OpenSubtitles](https://www.opensubtitles.com), and saves each next to its film or episode, where players such as IINA and VLC find them.

It needs a free OpenSubtitles account, and an API key from its **API consumers** page. OpenSubtitles limits how many subtitles a key can download each day.

```json title="package.json (part)"
{
  "hooks": [{ "name": "subtitles", "title": "Add subtitles", "event": "afterFinish" }],
  "permissions": {
    "files": "add",
    "network": ["api.opensubtitles.com", "www.opensubtitles.com"]
  },
  "preferences": [
    { "name": "apiKey", "type": "password", "title": "OpenSubtitles API key", "required": true },
    {
      "name": "language",
      "type": "dropdown",
      "title": "Language",
      "default": "en",
      "data": [
        { "title": "English", "value": "en" },
        { "title": "Spanish", "value": "es" },
        { "title": "French", "value": "fr" },
        { "title": "German", "value": "de" },
        { "title": "Malay", "value": "ms" }
      ]
    }
  ]
}
```

```ts title="src/subtitles.ts"
import { Download, DownloadFile, Result, fetch, files, getPreferenceValues, sleep } from "@orbtorrent/api";

const api = "https://api.opensubtitles.com/api/v1";
const videos = /\.(mkv|mp4|m4v|avi|mov)$/i;

interface Subtitle {
  attributes: { download_count: number; machine_translated: boolean; files: { file_id: number }[] };
}

/** Runs once a download finishes: subtitles for each film or episode in it. */
export default async function subtitles(download: Download): Promise<Result> {
  const { apiKey, language } = getPreferenceValues();
  // OpenSubtitles asks every app to name itself.
  const headers = { "Api-Key": apiKey, "User-Agent": "OrbTorrent Subtitles v1.0", "Content-Type": "application/json" };

  const wanted = download.files.filter((file) => file.wanted && videos.test(file.path) && !/\bsample\b/i.test(file.path));
  if (wanted.length === 0) return { status: "skipped", summary: "No films or episodes in this download" };

  const added: string[] = [];
  const there: string[] = [];
  for (const video of wanted) {
    // Subtitles that came with the download.
    if (download.files.some((file) => file.path === withSuffix(video, `.${language}.srt`))) {
      there.push(video.path);
      continue;
    }

    // OpenSubtitles wants its parameters in alphabetical order, in lower case.
    const query = new URLSearchParams({ languages: language, query: title(video).toLowerCase() });
    const search = await fetch(`${api}/subtitles?${query}`, { headers });
    if (search.status === 401 || search.status === 403) {
      return { status: "skipped", summary: "OpenSubtitles didn't accept the API key. Check it on the Extensions page" };
    }
    if (!search.ok) return { status: "skipped", summary: `OpenSubtitles didn't answer (status ${search.status})` };
    const best = ((await search.json()).data as Subtitle[])
      .filter((subtitle) => !subtitle.attributes.machine_translated && subtitle.attributes.files.length > 0)
      .sort((a, b) => b.attributes.download_count - a.attributes.download_count)[0];
    if (!best) continue;

    // Each download counts towards the key's daily limit.
    const ticket = await fetch(`${api}/download`, {
      method: "POST",
      headers,
      body: JSON.stringify({ file_id: best.attributes.files[0].file_id }),
    });
    if (!ticket.ok) {
      return finished(added, there, `OpenSubtitles stopped at its daily limit (status ${ticket.status})`);
    }
    const { link } = await ticket.json();
    const subtitle = await fetch(link);

    try {
      const saved = await files.save(video, `.${language}.srt`, await subtitle.text());
      added.push(saved.path);
    } catch {
      // Already there, such as subtitles the user added.
      there.push(video.path);
    }
    await sleep(1000);
  }
  return finished(added, there);
}

function finished(added: string[], there: string[], stopped?: string): Result {
  const details = [...added.map((path) => `- Added \`${path}\``), ...there.map((path) => `- Already had subtitles: \`${path}\``)].join("\n");
  if (added.length === 0) {
    return { status: "skipped", summary: stopped ?? (there.length > 0 ? "Already has subtitles" : "OpenSubtitles had none"), details };
  }
  const count = added.length === 1 ? "1 file" : `${added.length} files`;
  return { status: "passed", summary: `Added subtitles for ${count}${stopped ? `. ${stopped}` : ""}`, details, notify: true };
}

/** "Film.2024.1080p.WEB-DL.mkv" → "Film 2024 1080p WEB-DL", to search for. */
function title(file: DownloadFile): string {
  return file.path.split("/").pop()!.replace(/\.[^.]+$/, "").replace(/[._]+/g, " ").trim();
}

function withSuffix(file: DownloadFile, suffix: string): string {
  return file.path.replace(/\.[^./]+$/, "") + suffix;
}
```

Worth noticing:

- **`"files": "add"`** is all it asks for. It never reads the films, only their names.
- **It checks `download.files` first,** so a download that came with subtitles costs nothing from the daily limit.
- **`files.save` throws if a file is already there,** such as subtitles you added yourself. The hook catches it, and says so.
- **`notify: true`** tells you it's done, without opening the Checks tab.
- **Every way it can't finish is `skipped`,** with what happened, never `failed`: missing subtitles aren't something wrong with the download.

A test answers each request OpenSubtitles would get, and checks what was saved:

```json title="tests/adds-english-subtitles.json"
{
  "name": "Adds English subtitles next to a film",
  "download": {
    "name": "Film (2024)",
    "files": [
      { "path": "Film (2024)/Film.2024.1080p.WEB-DL.mkv", "size": 4000000000 },
      { "path": "Film (2024)/Sample/sample.mkv", "size": 20000000 }
    ]
  },
  "preferences": { "apiKey": "test-key" },
  "mocks": {
    "fetch": [
      {
        "url": "https://api.opensubtitles.com/api/v1/subtitles?languages=en&query=film+2024+1080p+web-dl",
        "json": { "data": [
          { "attributes": { "download_count": 90, "machine_translated": true, "files": [{ "file_id": 1 }] } },
          { "attributes": { "download_count": 40, "machine_translated": false, "files": [{ "file_id": 2 }] } }
        ] }
      },
      { "method": "POST", "url": "https://api.opensubtitles.com/api/v1/download", "json": { "link": "https://www.opensubtitles.com/download/abc/subfile/Film.srt", "remaining": 4 } },
      { "url": "https://www.opensubtitles.com/download/abc/subfile/Film.srt", "text": "1\n00:00:01,000 --> 00:00:03,000\nHello.\n" }
    ]
  },
  "expect": {
    "status": "passed",
    "summaryIncludes": "Added subtitles for 1 file",
    "saved": ["Film (2024)/Film.2024.1080p.WEB-DL.en.srt"],
    "savedIncludes": "Hello.",
    "notify": true
  }
}
```

To go further, match subtitles to the exact release, such as the same group or source as the file's name, as the agent's version did, and add a `verify` that checks the key.

## Ideas

Ideas the **Develop** tab suggests, and a few more. Each is a good first extension, by hand or [with a coding agent](/docs/extensions/coding-agents).

| Idea | Hook | Needs |
|---|---|---|
| **Hold `.scr` files**, which are programs in disguise. [The tutorial](/docs/extensions/getting-started) builds it. | `beforeStart` | Nothing |
| **Warn about tiny films,** smaller than 700 MB, since they're probably fake or poor quality. | `beforeStart` | Nothing |
| **Post to Discord when a download finishes,** with what its checks found. | `afterChecks` | `discord.com`, and a webhook setting |
| **Send a message to your phone** when a download finishes or is held, through ntfy.sh or Pushover. | `afterChecks` | `ntfy.sh` or `api.pushover.net`, and a topic or key setting |
| **Hold downloads over a size** while you're on a metered connection. | `beforeStart` | A setting |
| **Save synced lyrics** next to each song, as `.lrc` files players show line by line. | `afterFinish` | `"files": "add"`, and a lyrics service's host |
| **Save a poster** next to a film, for media servers, with `response.bytes()`. | `afterFinish` | `"files": "add"`, and the host of the artwork |
| **Tell your media server** to scan its library once a film finishes. | `afterFinish` | Your media server's public host, and an API key setting |
| **Check a finished file's fingerprint** against a list you trust, such as a Linux image's published checksums. | `afterFinish` | `"files": "contents"`, and the host of the list |

Extensions can only reach hosts on the internet, never your Mac or local network, so a media server on your own network can't be reached directly. For that, or to unpack or move what you download, OrbTorrent can [run a script of your own](/docs/guides/run-a-program) when a download finishes.

## Share yours

Made an extension others would like? [Package it](/docs/extensions/sharing), and add it to the **Community** list in OrbTorrent's README with a pull request.
