---
title: Settings
description: Every setting in OrbTorrent, what it does, and what it's set to when you first install it.
---

Open Settings with **More (…) › Settings…** in the menu bar panel, or **OrbTorrent › Settings…** (<kbd class="key">⌘,</kbd>) while the window is open. Changes take effect straight away.

Extensions' own settings are on the [Extensions page](/docs/guides/checks), not here.

## General

| Setting | What it does | At first |
|---|---|---|
| **Default torrent app** | **Make OrbTorrent the Default** opens magnet links and `.torrent` files in OrbTorrent. Once it is, it says so. | Asked when OrbTorrent first opens |
| **Open OrbTorrent when you log in** | Starts OrbTorrent in the menu bar when you log in, so downloads carry on. If macOS needs you to allow it, **Allow in Login Items Settings…** appears. | Asked when OrbTorrent first opens |

### Updates

| Setting | What it does | At first |
|---|---|---|
| **Check Now** | Checks for a new version now. The section shows your version and when it last checked. | |
| **Check for updates automatically** | Checks once a day. | On |
| **Download and install updates automatically** | Downloads updates as they're found, and restarts OrbTorrent to install them while you're not using it. Downloads carry on where they left off. | On |

### Help improve OrbTorrent

| Setting | What it does | At first |
|---|---|---|
| **Send anonymous counts with update checks** | Adds your version of macOS, the kind of Mac, the week OrbTorrent was installed and how often it quit unexpectedly to the daily update check. Never an ID, your IP address, or anything about your downloads or how you use OrbTorrent. | On |
| **See What's Sent…** | Shows exactly what the next check sends, value by value. [Privacy](/docs/guides/privacy#what-orbtorrent-counts) explains each. | |

### Adding torrents

| Setting | What it does | At first |
|---|---|---|
| **When you open a torrent** | **Ask before downloading** lets you choose the files and folder first. **Start downloading right away** doesn't ask. Extensions check downloads either way. | Ask before downloading |
| **Show the OrbTorrent window when a download is added** | Shows each new download in the window as it's added. | On |
| **Keep the Mac awake while downloading** | Stops your Mac going to sleep by itself while anything is downloading. The display can still sleep, and closing the lid still puts the Mac to sleep. | On |

### Deleting downloads

| Setting | What it does | At first |
|---|---|---|
| **When you delete a download** | **Move its files to the Trash**, where you can put them back, though they take up space until you empty it. Or **Delete its files permanently**: erased straight away, and they can't be put back. This applies everywhere in OrbTorrent. | Move its files to the Trash |

### Appearance

| Setting | What it does | At first |
|---|---|---|
| **Show OrbTorrent in the Dock while its window is open** | Turn off to keep OrbTorrent in the menu bar only. | On |
| **Show tidy download names** | Shows release names as what they are, such as **Orbit Station · Season 2** with a **4K HDR** badge, and episodes by their numbers. Turn off to see every name in full. [Tidy names](/docs/guides/library#tidy-names) explains. | On |

### Notifications

| Setting | What it does | At first |
|---|---|---|
| **Notify me when a download finishes** | Sends **Download Finished**, with **Open** and **Show in Finder**. Other notifications, such as for held downloads, are always sent. | On |

## Downloads

| Setting | What it does | At first |
|---|---|---|
| **Save downloads to** | Where new downloads go, unless you choose another folder when adding one. **Change…** picks a folder. | Your Downloads folder |
| **Pause downloads when the disk is almost full** | Pauses downloads when their disk gets down to 5 GB free, and resumes them once it has 7 GB. [Disk space](/docs/guides/disk-space) explains. | On |

### Seeding

| Setting | What it does | At first |
|---|---|---|
| **Stop sharing when the ratio reaches a limit** | Stops sharing a finished download once it's uploaded this many times what it downloaded. | Off |
| **Ratio limit** | Such as 2. | |
| **Then** | **Stop Seeding**, or **Remove Torrent**, which removes it from OrbTorrent and keeps its files. | |

### When a download finishes

| Setting | What it does | At first |
|---|---|---|
| **Run** | A program or script of your own, run as you after each download's checks, unless one of them failed. It gets the download's file or folder, and its name. **Choose…** picks it, and **Stop Running It** takes it away. [Run a program when a download finishes](/docs/guides/run-a-program) explains. | Nothing |
| **What it printed** | **Show Log** shows its log in Finder, once it's run. | |

## Speed

| Setting | What it does | At first |
|---|---|---|
| **Limit download speed** | With **Maximum download speed**, in KB/s, for every download together. | Off |
| **Limit upload speed** | With **Maximum upload speed**, in KB/s. Keeping uploads below your connection's maximum stops them slowing everything else. | On, at 5,000 KB/s |

## Network

### VPN

| Setting | What it does | At first |
|---|---|---|
| **Only download through a VPN** | Downloads and shares only over the VPN's connection, and stops if it drops. [Download only through a VPN](/docs/guides/vpn) explains. | Off |
| **VPN** | **Any VPN** that carries all your internet traffic, or one you choose. | Any VPN |
| **Status** | **Connected through …**, or **Not connected, so nothing is downloading**. | |
| **Incoming connections** | The port your VPN forwards, if any. | |
| **Forwarded port** | For VPNs that reserve a port in your account, such as AirVPN or Windscribe. Leave it empty, **Automatic**, for others. | Automatic |

### Connection

| Setting | What it does | At first |
|---|---|---|
| **Status** | **Reachable by peers**, **Incoming connections blocked**, or **Offline**. | |
| **Listening port** | The port peers connect to you on. **Random** picks a new one. Set aside while a VPN forwards a port. | |
| **Open the port on my router automatically (UPnP / NAT-PMP)** | Asks your router to forward the listening port. [Port forwarding](/docs/guides/port-forwarding) explains. | On |

### Peers

| Setting | What it does | At first |
|---|---|---|
| **Connect using** | **TCP and µTP**, **TCP Only** or **µTP Only**. | TCP and µTP |
| **Find peers through DHT** | Finds peers without a tracker. | On |
| **Exchange peers with other peers (PeX)** | Peers tell each other about the peers they know. | On |
| **Find peers on the local network** | Finds peers on your own network. | On |
| **Encryption** | **Prefer Encryption**, **Require Encryption** or **Disable Encryption**. | Prefer Encryption |
| **Find more peers for public torrents** | Adds trackers from a public list that's tested every day. Torrents from private trackers are never changed. [Find more peers](/docs/guides/peers) explains. | On |

### Limits

| Setting | What it does | At first |
|---|---|---|
| **Maximum connections** | Peers connected at once, across every download. At least 10. | 500 |
| **Per download** | Peers connected at once, for each download. At least 5. | 100 |

## Engine

| | What it does |
|---|---|
| **Download Engine** | Whether qBittorrent's engine is running, and the versions of qBittorrent, libtorrent, Qt, OpenSSL and Boost it's built from. |
| **Restart Engine** | Stops and starts the engine. Downloads carry on once it's back. |
| **Show Engine Log** | Opens the engine's log, which can say why something went wrong. |
| **Show Data Folder in Finder** | Shows the engine's folder, with its settings and your library. |
| **Import** | **Import…** brings downloads and settings over from Transmission or qBittorrent. [Switch from another app](/docs/get-started/switch) explains. |

## About

The same as **About OrbTorrent**: the version, **Acknowledgements** for the open-source projects inside OrbTorrent, **Source Code**, and **Privacy**.

## Reset OrbTorrent

To start again from scratch, quit OrbTorrent, then delete its folder and its settings in Terminal:

```sh title="Terminal"
rm -rf ~/Library/Application\ Support/OrbTorrent
defaults delete com.orbtorrent.mac
```

This removes your library, so OrbTorrent forgets your downloads, but **your downloaded files stay where they are**. Extension passwords stay in your Keychain until you remove them in **Keychain Access**. The next time you open OrbTorrent, it starts as if new.
