---
title: Privacy
description: What other people can see when you download, everything OrbTorrent connects to, and what stays on your Mac.
---

OrbTorrent knows nothing about you. There's no account, no ID and no crash reporting, and your library, settings and extension passwords stay on your Mac. Its daily update check carries a few anonymous counts. [The privacy page](/privacy) is the full statement, for the app and this website.

## What peers can see

BitTorrent is public by design. Everyone downloading a torrent can see the IP address of everyone else downloading it, and so can its trackers. That's true of every torrent app.

- **To hide your address,** download through a VPN, and turn on [Only download through a VPN](/docs/guides/vpn) so nothing goes over your normal connection if the VPN drops.
- **To hide what you download from your internet provider,** set **Encryption** to **Require Encryption** in **Settings › Network**. Peers and trackers still see your address.

## What OrbTorrent connects to

| | Why |
|---|---|
| **Peers and trackers** | For the downloads you add, as every torrent app does. |
| **raw.githubusercontent.com** | Once a day, for a public list of trackers, while **Find more peers for public torrents** is on. |
| **Web addresses you add torrents from** | To fetch the `.torrent` file. |
| **The sites an extension lists** | While it's on. Each extension's page shows them, and it can't reach any others. |
| **updates.orbtorrent.com** | Once a day, to check for a new version, while **Check for updates automatically** is on. It says which version of OrbTorrent it is, with [anonymous counts](#what-orbtorrent-counts). The address a check comes from isn't kept. |
| **github.com** | To download an update you install. |
| **download.db-ip.com** | Once a month, for a database of which country each IP address is in, to show peers' flags. Peers are looked up in it on your Mac, and never sent anywhere. |

That's everything. The same list is in the app, under **About OrbTorrent › Privacy**.

## What OrbTorrent counts

The update check adds a few anonymous counts, so we know how many Macs use OrbTorrent and whether a version has a problem: your version of macOS, whether your Mac has Apple silicon or Intel, the week OrbTorrent was installed, whether this is its first check this week or month, and how often it quit unexpectedly. None of them is an ID, and none is about your downloads or how you use OrbTorrent.

**Settings › General › See What's Sent** shows exactly what the next check sends, and **Send anonymous counts with update checks** turns them off. [The privacy page](/privacy#counts) lists every value.

## What stays on your Mac

- **Your library:** your downloads, their settings and their history.
- **Your settings,** and the download engine's.
- **Extension passwords and API keys,** in your Mac's Keychain rather than in a file.
- **Check results and extension logs.** Secrets are hidden in the logs.

[Files on your Mac](/docs/reference/files) lists where each is kept.

## The download engine

OrbTorrent runs qBittorrent's engine in the background, and talks to it through qBittorrent's Web API. The API only accepts connections from your own Mac, on `127.0.0.1`, and is protected by a random password OrbTorrent makes the first time it runs. Nothing on your network, or the internet, can reach it. [How OrbTorrent works](/docs/contribute/how-it-works) has the details.

## Extensions

Each extension can only reach the sites it lists, and only read the contents of your downloads if it says so. OrbTorrent enforces both, and shows them on the extension's page and before you install it. [Security model](/docs/extensions/security) explains how.

## Reporting a problem

**Help › Report a Problem** only opens your own mail app, with the report filled in. Nothing is sent until you send it, and you can read every word first. If you include the engine's log, IP addresses and your user name are hidden, though it can name your downloads. [Report a problem](/docs/help/report-a-problem) explains.
