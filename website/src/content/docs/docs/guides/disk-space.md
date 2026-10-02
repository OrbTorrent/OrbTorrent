---
title: Disk space
description: How OrbTorrent warns you when a download won't fit, pauses downloads before a disk fills up, and resumes them once there's room.
---

A torrent app that fills your disk can leave your Mac struggling, and a download that fails halfway. OrbTorrent looks after the space on every disk it saves to.

## Before a download starts

When OrbTorrent asks about a download, it shows how much room the disk has: "57.66 GB free on “Macintosh HD”". If the download won't fit, it says **Not enough space**, and how it would go:

- **"It would pause before finishing, to keep 5 GB free for your Mac,"** when it would fit, but only by leaving less than 5 GB free.
- **"It would run out of space before finishing,"** when it can't fit at all.

The space counted is what's free less what your unfinished downloads to that disk still need, so several large downloads can't each assume they'll get the same space. Free space is counted as Finder counts it, including space macOS can clear by itself.

Choose another folder with **Change…**, untick some files, or make room, then download.

## While downloads run

With **Pause downloads when the disk is almost full** on, in **Settings › Downloads**:

1. When a disk gets down to 5 GB free, OrbTorrent pauses the downloads saving to it, and sends a **Download Paused** notification.
2. The window's sidebar says **Disk almost full**. Point at it to see which disk.
3. Once the disk has 7 GB free, the downloads resume by themselves. The gap stops them pausing and starting as space comes and goes.

Downloads you paused yourself stay paused. The setting is on unless you turn it off, and turning it off resumes anything it paused.

## Make room

- Empty the Trash. Unless you've [changed it](/docs/reference/settings#deleting-downloads), downloads you remove put their files there, and they take up space until it's emptied.
- Remove finished downloads you've watched or installed.
- Move large downloads to another disk with **More › Move To…**.
- See what's using your disk in **System Settings › General › Storage**.

## Downloads on external disks

You can save downloads to any disk, including external ones. If a disk isn't connected, its downloads stop with an error until you connect it again, and OrbTorrent can't count its space until then.
