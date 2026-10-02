---
title: Results
description: What a hook returns, how each status shows in OrbTorrent, and how to write results people understand.
---

A hook returns a **result**, which OrbTorrent shows in the download's **Checks** tab, and in the confirmation before a download starts.

```ts
interface Result {
  status: "passed" | "warning" | "failed" | "skipped";
  summary: string;
  details?: string;
  link?: { title: string; url: string };
}
```

## Status

| Status | Means | Before it starts | After it finishes |
|---|---|---|---|
| `passed` | Nothing wrong. | The download starts. | Shown in the Checks tab. |
| `warning` | Worth a look. | The download starts, with a badge. | A notification. |
| `failed` | Something's wrong. | **The download is held** until the user decides. | A notification. |
| `skipped` | The check didn't apply, or couldn't run. | The download starts. | Shown in the Checks tab. |

A hook that throws, crashes or goes over a limit shows **Didn't finish**, with the reason, such as "Didn't finish: it took longer than 15 s". Before a download starts, that lets it start.

## Summary

One line, shown in the list of checks, in the confirmation, and in notifications. It's cut at 300 characters, and line breaks become spaces.

## Details

Optional, in Markdown, shown under the summary when the user opens the check. OrbTorrent draws:

- paragraphs, with lines wrapped by hand joined up;
- headings, with `#`, as bold lines;
- lists, with `- ` or `* `, and numbered lists, with `1. `;
- **bold**, *italic*, `code` and [links](https://orbtorrent.com) inside them.

Tables, images and code blocks aren't drawn. Details are cut at 20,000 characters, and the user can select and copy them.

## Link

Optional: a button under the details, such as `{ title: "Open VirusTotal Report", url: "https://…" }`. The title is cut at 60 characters, and the address must be `https://` or `http://`.

## Write results people understand

- **Say which file and why.** "Contains a program disguised as a video: Film.mp4.exe" tells the user what to look at. "Suspicious content detected" doesn't.
- **Use plain words, in sentence case, with no full stop** in the summary.
- **Use `failed` only when you're sure.** A false alarm that holds a download is worse than a missed warning. Use `warning` for "worth a look".
- **Before a download starts, a network error or a timeout means `skipped`, never `failed`.** The user's download shouldn't wait on your server.
- **Say when you skipped, and why,** such as "VirusTotal's daily limit was reached. Run it again later".
- **Don't put secrets or file contents in results.** They're shown, kept with the download, and copied with **Copy Result**.

## Examples

```ts
// Held before it starts.
{ status: "failed", summary: "Contains a screensaver, which is a Windows program: Play Me.scr" }

// Starts, with a badge.
{ status: "warning", summary: "Far too small for 1080p: 180 MB" }

// After it finishes, with the details and a report.
{
  status: "failed",
  summary: "12 of 70 engines flag setup.exe",
  details: "- `setup.exe`: 12 of 70 engines call it malicious. [Report](https://www.virustotal.com/gui/file/…)",
  link: { title: "Open VirusTotal Report", url: "https://www.virustotal.com/gui/file/…" },
}

// Couldn't run.
{ status: "skipped", summary: "VirusTotal didn't accept the API key. Check it on OrbTorrent's Extensions page" }
```

## Returning something else

If a hook returns anything without a `status` OrbTorrent knows and a `summary`, the check shows "Didn't finish: It returned something that isn't a result: return { status, summary }." TypeScript catches this before it happens, if your hook is typed `Promise<Result>`.
