---
title: Install OrbTorrent
description: Download OrbTorrent for macOS 26 or later, install it from its disk image, and set it up the first time it opens.
---

OrbTorrent is one universal app for Macs with Apple silicon or Intel. It's free, with no account and no ads.

## What it needs

| | |
|---|---|
| macOS | 26 (Tahoe) or later |
| Mac | Apple silicon or Intel |
| Price | Free and open source, under the GNU GPL |

OrbTorrent is built with this year's SwiftUI and Liquid Glass, so it can't run on earlier versions of macOS.

## Install it

1. Download the disk image from [orbtorrent.com/download](/download). It's called `OrbTorrent-<version>-universal.dmg`. Every version is also on [GitHub Releases](https://github.com/sanjevirau/OrbTorrent/releases), with its release notes.
2. Open the disk image, and drag **OrbTorrent** into the **Applications** folder.
3. Open OrbTorrent from your Applications folder. The first time, macOS asks whether you're sure you want to open an app from the internet, and says Apple checked it for malicious software. Click **Open**.

Every release is notarized by Apple, and every update is signed. If macOS won't open OrbTorrent, see [Troubleshooting](/docs/help/troubleshooting#macos-wont-open-orbtorrent).

## The first time it opens

A short welcome walks you through setting up:

1. **Bring your downloads over.** If OrbTorrent finds Transmission or qBittorrent on your Mac, it offers to bring their downloads over, and the settings of the one you used most recently. You see what would come over before anything changes. [Switch from another app](/docs/get-started/switch) has the details.
2. **Open torrents with OrbTorrent.** Click **Make Default**, and magnet links in your browser and `.torrent` files in Finder open in OrbTorrent.
3. **Start at login.** OrbTorrent waits quietly in the menu bar, so your downloads carry on after you restart your Mac.

You can change all of these later in [Settings](/docs/reference/settings). If you skip making OrbTorrent the default, a banner at the top of its window offers again, until you click **Not Now**.

## Where it lives

OrbTorrent lives in your **menu bar**, as a small orb that fills up as your downloads progress. Click it for your downloads and their speeds. [The menu bar](/docs/guides/menu-bar) explains what it shows.

The **OrbTorrent window** has your whole library, with each download's files, peers and trackers. Open it with **Open App** in the menu bar panel, or by opening OrbTorrent again from your Applications folder. While the window is open, OrbTorrent shows in the Dock.

Downloads keep going when the window is closed. To stop them all, quit OrbTorrent: click **More (…)** at the bottom of the menu bar panel, then **Quit OrbTorrent**.

## What it sets up

On its first launch, OrbTorrent sets its download engine up for a Mac:

- New downloads are saved to your **Downloads** folder.
- Uploads are limited to 5,000 KB/s, so sharing doesn't slow down the rest of your internet use. Downloads aren't limited.
- Your router's port is opened automatically, with UPnP or NAT-PMP, so other peers can reach you.
- OrbTorrent asks before each download, so you can choose its files and folder first.
- Deleted downloads' files go to the Trash.
- It finds more peers for public torrents, from a public list of trackers that's tested every day.

Every one of these is a setting. [Settings](/docs/reference/settings) lists them all.

## Updates

OrbTorrent checks for a new version once a day, and the update is signed, so your Mac knows it came from OrbTorrent. After an update, **What's New** shows what changed. [Updates](/docs/guides/updates) explains the settings.

## Next

- [Your first download](/docs/get-started/first-download)
- [Switch from Transmission or qBittorrent](/docs/get-started/switch)
- [Download only through a VPN](/docs/guides/vpn)
