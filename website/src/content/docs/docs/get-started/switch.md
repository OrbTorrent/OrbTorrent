---
title: Switch from Transmission or qBittorrent
description: Bring your downloads and settings over from Transmission or the qBittorrent app in one step, with their folders, file choices, labels and progress.
---

OrbTorrent brings your downloads over from **Transmission** or the **qBittorrent** app in one step, with the settings you choose. Your files stay where they are: nothing is copied or moved.

## When to import

- **The first time OrbTorrent opens,** it looks for both apps on your Mac and offers to bring their downloads over, with the settings of the one you used most recently.
- **Any time after,** choose **File › Import From › Transmission…** or **qBittorrent…**, or click **Import…** in **Settings › Engine**.

An app shows as **Not on this Mac** if OrbTorrent can't find its downloads or settings.

## What comes over

| | |
|---|---|
| **Where each one is saved** | Files stay where they are. Nothing is copied or moved. |
| **The files you chose** | Files you skipped stay skipped. |
| **Names and labels** | Renamed downloads keep their names, and labels come too. |
| **Limits and history** | Speed limits, when each was added, and how much it's downloaded and shared, so ratios carry on. |
| **Progress** | qBittorrent's comes over as it is. Transmission's downloads have their files checked first, then carry on. Downloads that were stopped stay stopped. |

Downloads OrbTorrent already has are left out, so importing again only brings over what's new.

## Settings, if you want them

Before anything changes, you see each of the other app's settings that's different from OrbTorrent's, and choose which ones come over. Anything you leave keeps OrbTorrent's own.

These settings can come over:

- Save downloads to
- Download and upload speed limits
- Ratio limit, and what happens when it's reached
- Listening port, and opening it on your router automatically
- Connect using (TCP and µTP)
- Find peers through DHT, peer exchange (PeX) and on the local network
- Encryption
- Maximum connections, and connections per download

While you [download through a VPN](/docs/guides/vpn) that forwards a port, the listening port stays the VPN's, so it isn't offered.

## How it goes

1. **Choose what comes over.** The import sheet lists the downloads that would come over and the settings that would change. Untick any setting you'd rather keep.
2. **Import.** The other app quits while it happens, so the two don't use the same files. The button says **Quit Transmission and Import** or **Quit qBittorrent and Import** while it's open.
3. **Carry on.** Your downloads carry on in OrbTorrent. Transmission's are checked first, and each goes on once its files have been checked.

The other app keeps its own list. You can open it again afterwards, though only one app should download a torrent at a time.

## Where OrbTorrent looks

| App | Downloads | Settings |
|---|---|---|
| Transmission | `~/Library/Application Support/Transmission` | Transmission's preferences |
| qBittorrent | `~/Library/Application Support/qBittorrent/BT_backup` | `~/.config/qBittorrent/qBittorrent.ini` |

## If something doesn't come over

- **"There's nothing new to bring over."** OrbTorrent already has that app's downloads, and its settings match.
- **A download is missing its files, or starts again from the beginning.** OrbTorrent looks for its files where the other app saved them. If you've moved them since, move them back, then select the download and choose **More › Verify Local Data**, which [checks what's on disk](/docs/guides/download-details#actions).

## From µTorrent or another app

OrbTorrent can't import from other apps, such as µTorrent. Open each download's magnet link or `.torrent` file in OrbTorrent instead, and choose the folder the other app saved it in. OrbTorrent checks the files already there, and downloads only what's missing.

To see how OrbTorrent compares first, there are pages for [µTorrent](/utorrent-for-mac), [qBittorrent](/qbittorrent-for-mac) and [Transmission](/transmission-for-mac).
