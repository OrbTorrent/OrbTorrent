---
title: Troubleshooting
description: Fixes for the usual problems with OrbTorrent, from magnet links that don't open and slow downloads to the VPN, the download engine and extensions.
---

Most problems have a quick fix. Find yours below, and if it isn't here, [report it](/docs/help/report-a-problem).

## Installing and opening

### macOS won't open OrbTorrent

- **It says you can't use this version of OrbTorrent with this version of macOS.** OrbTorrent needs macOS 26 (Tahoe) or later. If your Mac can run it, update in **System Settings › General › Software Update**.
- **It says OrbTorrent is damaged, or that it can't check it for malicious software.** Every copy of OrbTorrent from orbtorrent.com and GitHub is notarized by Apple, so that copy came from somewhere else, or was changed. Move it to the Trash and download OrbTorrent again from [orbtorrent.com/download](/download).

### Magnet links open another app, or nothing

Make OrbTorrent your default torrent app: **Settings › General › Make OrbTorrent the Default**. Then click the magnet link again. Some browsers ask the first time which app to open a link with: choose OrbTorrent, and tick that it should always open them.

### A `.torrent` file opens in another app

Same fix: make OrbTorrent the default. Or right-click the file in Finder and choose **Open With › OrbTorrent**.

### Nothing happens when I open OrbTorrent

OrbTorrent lives in the menu bar: look for the orb near the clock. If the menu bar is full, macOS may hide it behind other icons. Opening OrbTorrent again from your Applications folder opens its window.

## Downloads

### A download is slow

See [Find more peers](/docs/guides/peers#if-a-download-is-slow), which goes through the causes in order: few people sharing it, a closed port, speed limits, and the rest.

### It's stuck on "Fetching Info"

A magnet link needs a peer to send its file list. If it stays on **Fetching Info**:

- **Check you're online,** and if you [download only through a VPN](/docs/guides/vpn), that the VPN is connected.
- **Ask for more peers:** right-click it and choose **More › Ask Trackers for More Peers**.
- **Leave it a while.** An old or unpopular torrent may have nobody sharing it right now.

### It's stuck on "Waiting for Peers"

It's running, but no one is sending it anything. Look at **Seeds** and **Availability** on its **Details** tab. If nobody has the whole download, it can only wait. Otherwise, work through [If a download is slow](/docs/guides/peers#if-a-download-is-slow).

### A download says "Files Missing"

Its files were moved, renamed or deleted outside OrbTorrent, or they're on a disk that isn't connected. Connect the disk, or move the files back, then right-click the download and choose **More › Verify Local Data**. Next time, move downloads with **More › Move To…**, so OrbTorrent keeps track of them.

### A download has an error

The usual causes:

- **The disk is full.** Make room, then resume it. [Disk space](/docs/guides/disk-space) explains how OrbTorrent avoids this.
- **The disk isn't connected.** Connect it, then resume the download.
- **OrbTorrent isn't allowed to use the folder.** If macOS asked whether OrbTorrent could access a folder such as Downloads or Documents and you chose **Don't Allow**, turn it on in **System Settings › Privacy & Security › Files & Folders › OrbTorrent**.

The download's status and the engine's log, in **Settings › Engine › Show Engine Log**, say more.

### Downloads paused by themselves

Something paused them on purpose:

- **The disk was almost full.** They resume by themselves once it has 7 GB free. The sidebar says **Disk almost full**.
- **A check held one** before it started. The menu bar panel says so: see [Checks and held downloads](/docs/guides/checks#a-held-download).
- **The VPN dropped,** if you download only through one. They carry on once it's back.
- **A finished download reached its ratio limit,** if you've set one in **Settings › Downloads**.

### A download was held, and I'd like it

Open its **Checks** tab, read what the check found, and click **Download Anyway** if you're sure. If a check keeps holding downloads you trust, turn that extension off on the [Extensions page](/docs/guides/checks#turn-extensions-off).

## Network and VPN

### It says "Waiting for VPN"

You've turned on **Only download through a VPN**, and OrbTorrent can't find the VPN's connection, so nothing downloads.

- **Connect the VPN.** Downloads carry on by themselves once it's connected.
- **If it's connected,** check **Settings › Network › VPN**. If you chose a VPN by name, it must be that one. **Any VPN** only uses a VPN that carries all your internet traffic, so a split tunnel doesn't count.
- **To download without the VPN,** turn off **Only download through a VPN**.

### "Incoming connections blocked"

Downloads work, but only peers with open ports can reach you, which can make them slower. Your router or internet provider is blocking incoming connections. [Port forwarding](/docs/guides/port-forwarding) explains the fixes, at home and through a VPN.

### "No port forwarded" through my VPN

Your VPN didn't forward a port. Check it offers port forwarding on your plan and server, turn it on in its app if it has a setting, or enter a port you've reserved in your VPN account. [Port forwarding](/docs/guides/port-forwarding#if-no-port-is-forwarded) has the details.

### It says "Offline"

OrbTorrent can't reach the internet. Check your Wi-Fi or network, and your VPN if you use one.

## The app

### The download engine stopped

OrbTorrent downloads with qBittorrent's engine, which runs in the background, and restarts it if it stops. If the menu bar panel says **Download engine stopped**:

1. Click **Restart**, or **Restart Engine** in **Settings › Engine**.
2. If it stops again, look at the engine's log: **Settings › Engine › Show Engine Log**.
3. [Report the problem](/docs/help/report-a-problem), with the log included.

### The window won't open

Click the orb in the menu bar, then **Open App**. If OrbTorrent isn't responding, quit it from **Activity Monitor** and open it again: your downloads carry on where they stopped.

### No notifications

Check **System Settings › Notifications › OrbTorrent**, and that **Allow notifications** is on. **Download Finished** also needs **Notify me when a download finishes** in **Settings › General**.

### My Mac doesn't sleep while downloading

That's **Keep the Mac awake while downloading**, in **Settings › General**. Turn it off to let your Mac sleep, which pauses downloading until it wakes.

## Extensions

### An extension didn't finish

The check failed, or took longer than it's allowed. A check that doesn't finish never stops a download.

- Open the extension's page, on the [Extensions page](/docs/guides/checks), and read its **Logs**.
- Click **Run Again** in the download's **Checks** tab.
- If it keeps happening, tell whoever made it. For the official extensions, [report a problem](/docs/help/report-a-problem).

### An extension says "Needs setup"

It needs a setting, such as an API key, before it can run. Its checks are skipped until then. Open its page, fill in the setting, and click **Verify** if there is one.

### VirusTotal Scan skipped files

The free VirusTotal key allows 500 lookups a day. Once they're used up, the scan skips the rest, and **Run Again** tomorrow picks them up, reusing the answers it already has. Choose **Programs, archives and documents** in its settings to save lookups.

### An extension says it needs a newer OrbTorrent

It was built for a newer extension API than your OrbTorrent has. Update OrbTorrent: **OrbTorrent › Check for Updates…**.

## Still stuck?

Choose **Help › Report a Problem**, or [open an issue](https://github.com/orbtorrent/OrbTorrent/issues/new/choose) on GitHub. [Report a problem](/docs/help/report-a-problem) explains what helps.
