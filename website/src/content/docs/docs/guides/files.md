---
title: Choose files and their order
description: Download only the files you want, give some priority, and download a torrent's files one after another, or a video in order to watch while it downloads.
---

A torrent can hold many files. You don't have to download them all, and you can choose which come first.

## Before it starts

When OrbTorrent asks about a new download, untick the files you don't want. **Select All** and **Select None** are above the list, and the total updates as you go: "3 files · 1.2 GB of 4.5 GB selected".

[Your first download](/docs/get-started/first-download#choose-what-to-download) shows the whole confirmation.

## While it downloads

The **Files** tab in the inspector, and the panel you see when you click a download in the menu bar, list every file. Each has a checkbox, and a circle at its end that shows its state:

| Circle | Means |
|---|---|
| Green tick | Finished. Its menu has **Open** and **Show in Finder**. |
| Arrow | Downloading at **Normal** priority. |
| Chevron | **High** priority, in orange. |
| Filled chevron | **Maximum** priority, in orange. |
| Cross | **Don't Download**: skipped. |

Click the circle to change a file's priority. Higher priority files get their pieces first; files at the same priority share the connection.

**Untick a file** to skip it. A file you skip after part of it has downloaded keeps what it has, and picks up from there if you tick it again.

To change several files at once, select them, then right-click:

- **Open** and **Show in Finder**
- **Download 3 Files** or **Skip 3 Files**
- **Priority**
- **Download All Files** or **Skip All Files**

## One after another

To download a torrent's files one at a time, such as the episodes of a series in order, turn on **Download Files in Order** above the file list.

1. Drag the files into the order you want. The top one downloads first.
2. OrbTorrent gives the first unfinished file **Maximum** priority, the next **High**, and the rest **Normal**. As each finishes, the next moves up.
3. To jump a file to the front, choose **Download This Next** from its circle or its right-click menu.

Point at a file's circle to see its place: "Downloading first", "Downloading next", or "Number 4 in the download order". Turn the switch off to go back to priorities you set yourself.

## Watch while it downloads

A torrent normally arrives in pieces from all over its files, whichever peers have. To play a video before it's finished, download its pieces **in order** instead:

- **When adding it** in the window, tick **Download in order, to watch while it downloads**.
- **Afterwards,** right-click it and choose **Download Sequentially**, or turn on **Download pieces in order** in the **Details** tab.

Also turn on **Get first and last pieces first**, in the **Details** tab, so your media player can read the file's header and index straight away.

:::note
Downloading in order can be slower, because the pieces you need next may be ones few peers have. Turn it off once you've watched what you wanted.
:::

## Open part of a download

You can open any file that has started arriving, from its circle, its right-click menu, or by clicking it in the menu bar panel. Most players can play a video that's downloading in order. Other files may not open properly until they've finished.
