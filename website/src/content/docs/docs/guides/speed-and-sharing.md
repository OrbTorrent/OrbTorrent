---
title: Speed limits and sharing
description: Limit OrbTorrent's download and upload speeds, and stop sharing a finished download once it reaches a ratio.
---

BitTorrent works because everyone shares what they download. OrbTorrent shares, or **seeds**, finished downloads until you pause them, remove them, or set a limit.

## Speed limits

In **Settings › Speed**:

- **Limit download speed**, with **Maximum download speed** in KB/s. Off unless you turn it on.
- **Limit upload speed**, with **Maximum upload speed** in KB/s. OrbTorrent starts with uploads limited to 5,000 KB/s.

Keeping uploads below your connection's maximum stops them slowing down your downloads and the rest of your internet use. If you don't know your connection's upload speed, run a speed test, and set the limit to about three-quarters of it.

The limits apply to every download together. 1,000 KB/s is about 1 MB/s.

## Stop sharing at a ratio

A download's **ratio** is how much you've uploaded divided by how much you've downloaded: 1.00 means you've given back as much as you took.

In **Settings › Downloads › Seeding**, turn on **Stop sharing when the ratio reaches a limit**, then set:

- **Ratio limit**, such as 2.
- **Then**: **Stop Seeding**, which keeps the download and its files, or **Remove Torrent**, which removes it from OrbTorrent and keeps its files.

The limit applies to every download. A download's ratio is on its **Details** tab, and in its status line once it's finished: "Seeding · 6.48 GB · Ratio 1.20".

## Pause and resume

- **One download:** its **Pause** button, in the menu bar panel or the inspector.
- **Several:** select them in the window, then **Pause** in the toolbar.
- **Everything:** **Pause All** in the menu bar panel, or **Downloads › Pause All** (<kbd class="key">⌥⌘.</kbd>). **Resume All** (<kbd class="key">⌥⌘R</kbd>) starts them again.

A paused download keeps what it has, and picks up where it stopped.

## Private trackers

Private trackers usually ask you to keep up a ratio, and count what you upload. If you use one, set any ratio limit above what it asks, or leave the limit off. OrbTorrent never adds trackers to their torrents, and they don't use DHT or peer exchange.
