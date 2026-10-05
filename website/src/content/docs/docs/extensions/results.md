---
title: Results
description: What a hook returns, how each status shows in OrbTorrent, how to mark the files it's about, and how to write results people understand.
---

A hook returns a **result**, which OrbTorrent shows in the download's **Checks** tab, and in the confirmation before a download starts.

```ts
interface Result {
  status: "passed" | "warning" | "failed" | "skipped";
  summary: string;
  details?: string;
  link?: { title: string; url: string };
  notify?: boolean;
  files?: FileResult[];
}
```

## Status

| Status | Means | Before it starts | After it finishes |
|---|---|---|---|
| `passed` | Nothing wrong. | The download starts. | Shown in the Checks tab, and as a notification with `notify: true`. |
| `warning` | Worth a look. | The download starts, with a badge. | A notification, unless it's nothing new. |
| `failed` | Something's wrong. | **The download is held** until the user decides. | A notification, unless it's nothing new. |
| `skipped` | The check didn't apply, or couldn't run. | The download starts. | Shown in the Checks tab, and as a notification with `notify: true`. |

A hook that throws, crashes or goes over a limit shows **Didn't finish**, with the reason, such as "Didn't finish: it took longer than 15 s". Before a download starts, that lets it start.

"Nothing new" is a run after the user chose more of a download's files that finds what an earlier run found already: the same files, no worse. The user was told the first time.

An [`afterChecks` hook's](/docs/extensions/hooks#once-its-checks-are-done) result reports on the checks rather than being one. It shows under **After its checks**, never holds a download, and sends a notification only with `notify: true`.

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

## Files

Optional: what the hook found about particular files. OrbTorrent marks each problem beside its file, in the download's Files tab, in the menu bar, and before it starts in the confirmation, and lists them in the check with **Show in Finder** and each file's link.

```ts
return {
  status: "failed",
  summary: "12 of 70 engines flag setup.exe",
  files: [
    { file: setup, status: "failed", summary: "12 of 70 engines call it malicious", link: { title: "VirusTotal Report", url: report } },
    { file: readme, status: "passed" },
  ],
};
```

- **`file`** is a file from `download.files`, or its `index`. Naming one that isn't there makes the check **Didn't finish**, with "Its result's “files” names a file that isn't part of this download."
- **`status`** is `passed`, `warning` or `failed`. Files that passed show as a count, such as "14 other files passed".
- **`summary`** says why in a few words, and is cut at 300 characters. **`link`** follows the same rules as the result's.
- **A result is never better than its worst file.** One that says `passed` with a `failed` file shows as failed, and the extension's log says why.
- **Each result replaces the hook's last one,** so name every file you know about, not only the [new ones](/docs/extensions/hooks#after-a-download-finishes). Up to 1,000 files are kept, problems first.

## Notification

`notify: true` also shows the summary as a notification, titled with the extension's name, with the download's name under it. Clicking it opens the download's Checks tab.

```ts
{ status: "passed", summary: "Added English subtitles", notify: true }
```

Use it for news the user wants without looking, such as subtitles or artwork the extension added. Some results are notifications already, so they don't need it: a warning or failure after a download finishes, and a download held before it starts. Only a warning or failure makes a sound.

## Write results people understand

- **Say which file and why.** "Contains a program disguised as a video: Film.mp4.exe" tells the user what to look at. "Suspicious content detected" doesn't. Put the file in `files` too, so OrbTorrent can mark it.
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

// After it finishes, with the file it found and a report.
{
  status: "failed",
  summary: "12 of 70 engines flag setup.exe",
  link: { title: "Open VirusTotal Report", url: "https://www.virustotal.com/gui/file/…" },
  files: [{ file: 0, status: "failed", summary: "12 of 70 engines call it malicious" }],
}

// Couldn't run.
{ status: "skipped", summary: "VirusTotal didn't accept the API key. Check it on OrbTorrent's Extensions page" }
```

## Returning something else

If a hook returns anything without a `status` OrbTorrent knows and a `summary`, the check shows "Didn't finish: It returned something that isn't a result: return { status, summary }." TypeScript catches this before it happens, if your hook is typed `Promise<Result>`.
