---
title: A download's details
description: The inspector shows one download in full, with its files, transfer details, peers, trackers and checks, and the actions you can take on it.
---

Select a download in the library to see it in the **inspector**, on the right of the window. Show or hide it with the **Inspector** button in the toolbar, or <kbd class="key">⌘I</kbd>.

At the top are the download's name and status, and four buttons: **Pause** or **Resume**, **Open**, **Finder** and **Remove**. Below them are its tabs.

Select several downloads and the inspector shows how many, their total size and how much is left, with **Remove…** for all of them.

## Files

Every file in the download, with its size and state. [Choose files and their order](/docs/guides/files) explains everything you can do here: skipping files, setting priorities and downloading in order.

A magnet link has no files to show until peers send its details: "The file list appears once peers send the torrent's details."

## Details

**Transfer**

| | |
|---|---|
| **Size** | The size of the files you're downloading, and of the whole torrent if you've skipped some. |
| **Downloaded** and **Uploaded** | How much this download has received and sent, in all. |
| **Ratio** | Uploaded divided by downloaded. 1.00 means you've shared as much as you took. |
| **Seeds** and **Peers** | How many you're connected to, of how many the trackers know about. |
| **Availability** | How many full copies of the download the peers you're connected to have between them. Below 1, no one has all of it right now. |
| **Time Active** | How long it's been running. |
| **Average Speed** | Its download speed, on average, while active. |
| **Wasted** | Data that arrived damaged, or twice, and was thrown away. |

**Options**

- **Download pieces in order.** Downloads the start of the files first, so you can watch a video while it downloads.
- **Get first and last pieces first.** Lets a media player read a file's header and index early.

**Location** shows the folder its files are saved in, with **Show** to open it in Finder.

**Torrent** has its full **Name**, when it was added and completed, when the torrent was made and by what, its pieces, whether it's **Private** (from a private tracker), its comment, and its **Info Hash**, the fingerprint that identifies it.

## Peers

The people you're connected to for this download: each one's country flag, address, how much of the download they have, the app they use, whether you're connected over TCP or µTP, and how fast data goes each way. A lock means the connection is encrypted.

Above the list, three counts:

- **Seeding:** peers that have the whole download.
- **µTP:** peers connected over µTP, BitTorrent's protocol that eases off when your connection is busy.
- **Incoming:** peers that connected to you. Behind a closed port, these arrive through µTP hole punching. [Port forwarding](/docs/guides/port-forwarding) brings more.

Peers' countries come from a database of IP addresses that OrbTorrent downloads once a month and looks up on your Mac. Nothing about your peers is sent anywhere.

## Trackers

The servers that introduce you to other peers, and how each one is doing: **Working**, **Updating**, **Not Contacted Yet**, **Not Working**, **Tracker Error** or **Unreachable**. Point at one to see its full address and its last message.

Under **Peer Discovery** are the other ways OrbTorrent finds peers: **DHT**, **PeX** (peer exchange) and **LSD** (local peers). [Find more peers](/docs/guides/peers) explains each.

**Ask for More Peers** asks every tracker for more peers now, rather than at its next scheduled time.

## Checks

What your extensions found when they checked this download, before it started and after it finished. The tab shows while extensions are on. [Checks and held downloads](/docs/guides/checks) explains.

## Actions

These are in the **More** submenu when you right-click a download, and some are on the **Details** tab too:

- **Ask Trackers for More Peers.** Asks every tracker for peers straight away.
- **Verify Local Data.** Checks every piece already on disk against the torrent, and downloads again any that don't match. Use it after moving files outside OrbTorrent, or if you think something's damaged.
- **Move To….** Moves the download's files to another folder, and carries on from there. Use this rather than moving them in Finder, so OrbTorrent keeps track of them.
- **Copy Name.** Copies the download's full name, even when it [shows a tidy one](/docs/guides/library#tidy-names).
- **Copy Magnet Link.** Copies a link anyone can use to download the same thing.
