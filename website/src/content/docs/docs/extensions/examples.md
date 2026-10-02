---
title: Examples
description: The templates and official extensions to learn from, and ideas for extensions to build, from holding fakes to notifying your phone.
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

## Ideas

Ideas the **Develop** tab suggests, and a few more. Each is a good first extension, by hand or [with a coding agent](/docs/extensions/coding-agents).

| Idea | Hook | Needs |
|---|---|---|
| **Hold `.scr` files**, which are programs in disguise. [The tutorial](/docs/extensions/getting-started) builds it. | `beforeStart` | Nothing |
| **Warn about tiny films,** smaller than 700 MB, since they're probably fake or poor quality. | `beforeStart` | Nothing |
| **Post to Discord when a download finishes.** | `afterFinish` | `discord.com`, and a webhook setting |
| **Hold downloads over a size** while you're on a metered connection. | `beforeStart` | A setting |
| **Tell your media server** to scan its library once a film finishes. | `afterFinish` | Your media server's public host, and an API key setting |
| **Check a finished file's fingerprint** against a list you trust, such as a Linux image's published checksums. | `afterFinish` | `"files": "contents"`, and the host of the list |

Extensions can only reach hosts on the internet, never your Mac or local network, so a media server on your own network can't be reached directly.

## Share yours

Made an extension others would like? [Package it](/docs/extensions/sharing), and add it to the **Community** list in OrbTorrent's README with a pull request.
