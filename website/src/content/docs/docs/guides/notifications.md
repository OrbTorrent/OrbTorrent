---
title: Notifications
description: The notifications OrbTorrent sends, what each one's buttons do, and how to turn them on or off.
---

OrbTorrent sends a notification when something needs you, or when a download is done. macOS asks the first time whether to allow them.

## What it sends

| Notification | When | Its buttons |
|---|---|---|
| **Download Finished** | A download has every file you wanted. | **Open** and **Show in Finder** |
| **Download Held** | A check held a download before it started. It says which check, and what it found. | **Download Anyway** and **Remove…** |
| A check's name, such as **VirusTotal Scan** | A check on a finished download failed, or warned. | Click it for the download's checks. |
| **Download Paused** | Downloads paused because their disk is almost full. | They resume by themselves once there's room. |
| **OrbTorrent … Is Available** | A new version was found while OrbTorrent was in the background. | Click it to see what's new and install it. |

Clicking a notification about a download opens it in OrbTorrent. One about a check opens on the download's **Checks** tab.

## Turn them on or off

- **Download Finished** follows **Notify me when a download finishes** in **Settings › General**. It's on unless you turn it off.
- The others are always sent, because each one needs you. To silence them, or change how they look, go to **System Settings › Notifications › OrbTorrent**.

If no notifications appear at all, check **System Settings › Notifications › OrbTorrent**, and that **Allow notifications** is on.

## Related

- [Checks and held downloads](/docs/guides/checks)
- [Disk space](/docs/guides/disk-space)
- [Updates](/docs/guides/updates)
