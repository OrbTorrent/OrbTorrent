---
title: Find more peers
description: How OrbTorrent finds people to download from, how its public tracker list speeds up slow downloads, and what to try when a download is slow.
---

A download comes from **peers**: other people with the same torrent. The more peers you can reach, and the more of them have the whole download, the faster it goes.

## How OrbTorrent finds peers

- **Trackers.** Servers listed in the torrent that introduce its peers to each other.
- **DHT.** A network shared by every BitTorrent app, which finds peers without a tracker. Trackerless magnet links rely on it.
- **Peer exchange (PeX).** Peers you're connected to tell you about the peers they know.
- **Local peer discovery (LSD).** Finds peers on your own network, such as another Mac at home.

All four are on unless you turn them off, in **Settings › Network › Peers**. A download's **Trackers** tab shows how each is doing. Downloads from private trackers only use their own trackers, as private trackers ask.

## Find more peers for public torrents

Many public torrents list trackers that have stopped working, so they find few peers. **Find more peers for public torrents** adds trackers from a public list that's tested every day, [ngosang/trackerslist](https://github.com/ngosang/trackerslist): the most popular public trackers that answered that day's test.

- It's on unless you turn it off, in **Settings › Network**. The setting says how many trackers the list has, and when it was updated.
- The trackers are added after a torrent's own, so its own are asked first.
- **Torrents from private trackers are never changed.** OrbTorrent only adds the list once a torrent is known to be public. A magnet link counts as public straight away only if none of its trackers carries a personal key, as a private tracker's address does. If a magnet link turns out to be private, the trackers come off again.
- OrbTorrent downloads the list once a day while the setting is on, and keeps the last good copy. It comes with a copy, for its first launch and for when the list can't be reached.
- Turn the setting off and every tracker it added comes off again. A tracker that drops off the list comes off too.

## Ask for more peers now

Trackers are asked for peers every so often. To ask straight away, right-click a download and choose **More › Ask Trackers for More Peers**, or click **Ask for More Peers** on its **Trackers** tab.

## If a download is slow

Work through these, roughly in order:

1. **Look at its peers.** In the **Details** tab, **Seeds** says how many peers have the whole download, and **Availability** how many full copies the peers you're connected to have between them. Below 1, no one you're connected to has all of it, and it may wait for someone who does. An old or unpopular torrent may simply have few people sharing it.
2. **Open your port.** Peers can only connect to you if your port is open. Check that **Settings › Network** says **Reachable by peers**. [Port forwarding](/docs/guides/port-forwarding) explains, at home and through a VPN.
3. **Check your speed limits.** In **Settings › Speed**, make sure **Limit download speed** is off, or high enough. Uploading near your connection's maximum can also slow downloads, which is why OrbTorrent limits uploads to 5,000 KB/s at first.
4. **Turn on Find more peers for public torrents,** if you've turned it off.
5. **Ask trackers for more peers.**
6. **Through a VPN,** try a server closer to you, or one that forwards ports.
7. **Downloading in order** is slower, because the pieces you need next may be ones few peers have. [Turn it off](/docs/guides/files#watch-while-it-downloads) once you've watched what you wanted.

## Connection settings

In **Settings › Network**:

| Setting | |
|---|---|
| **Connect using** | **TCP and µTP**, **TCP Only** or **µTP Only**. µTP eases off when your connection is busy, so other apps stay quick. |
| **Encryption** | **Prefer Encryption**, **Require Encryption** or **Disable Encryption**. Requiring it hides what you're downloading from your internet provider, but rules out peers that don't encrypt. |
| **Maximum connections** | Peers connected at once, across every download. |
| **Per download** | Peers connected at once, for each download. |

Leave these as they are unless you have a reason: they suit most connections.
