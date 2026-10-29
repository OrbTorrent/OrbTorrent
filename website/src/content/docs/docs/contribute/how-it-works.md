---
title: How OrbTorrent works
description: How OrbTorrent is put together, from its SwiftUI app and qBittorrent's engine to the sandboxed extension host and signed updates.
---

OrbTorrent is a native Mac app, written in Swift and SwiftUI, that runs qBittorrent's download engine in the background. Here's how the parts fit. [How OrbTorrent is built](/how-its-built) tells the longer story, with the reasons and excerpts of the code.

## The parts

```
OrbTorrent.app
├── Contents/MacOS/OrbTorrent              the app: menu bar, window, settings
├── Contents/MacOS/qbittorrent-nox         qBittorrent's engine, without its interface
├── Contents/MacOS/orb-extension-host      runs extensions, sandboxed
├── Contents/Frameworks/Sparkle.framework  updates
└── Contents/Resources/Extensions/         the official extensions
```

Everything ships inside the one app. The engine is statically linked, so it depends only on macOS itself.

## The download engine

OrbTorrent downloads with **qBittorrent's engine**, `qbittorrent-nox`, built from qBittorrent's released source with libtorrent, Qt, OpenSSL and Boost. It does the BitTorrent work: µTP, DHT, peer exchange, local peer discovery, web seeds, encryption, and UPnP and NAT-PMP.

- **OrbTorrent starts it** as a background process, with its own profile in `~/Library/Application Support/OrbTorrent/Engine`, so it never touches a qBittorrent app you also have.
- **It talks to it through qBittorrent's Web API,** which listens on `127.0.0.1` only, on a random free port, so nothing on your network can reach it.
- **The API is protected by a random password** that OrbTorrent makes the first time it runs, stored in qBittorrent's PBKDF2 format, and readable only by you.
- **When OrbTorrent quits,** it asks the engine to shut down, so each download's progress is always saved. If the engine crashes, OrbTorrent restarts it.

OrbTorrent isn't affiliated with or endorsed by the qBittorrent project. The versions it's built from are on **Settings › Engine**, and in **About OrbTorrent › Acknowledgements**, with their licences.

## The app

The app is SwiftUI, with Liquid Glass. It asks the engine for the state of every download once a second, and draws the menu bar orb, the panel and the window from it. What only OrbTorrent does, it does itself, outside the engine:

- **Download only through a VPN.** OrbTorrent watches your Mac's network state and routes, finds the VPN, and binds the engine to its network interface before the engine starts.
- **VPN port forwarding.** It asks the VPN's gateway for a port over NAT-PMP, or reads it from Private Internet Access, renews it, and sets the engine's listening port to match.
- **Disk space.** It counts what each unfinished download still needs, warns before one won't fit, and pauses downloads before a disk fills.
- **Finding more peers.** It downloads a public tracker list each day, and adds it to public torrents only.
- **Download order.** It turns the order you drag files into into the engine's four priorities, as each file finishes.
- **Importing.** It reads Transmission's and qBittorrent's files directly, and adds their downloads to the engine with their progress.

## Extensions

Extensions run in **`orb-extension-host`**, a small helper with JavaScriptCore and the App Sandbox. OrbTorrent starts a fresh one for every run of a hook. The helper can't read files, reach the network or look up a host name: it asks OrbTorrent for everything, and OrbTorrent checks each request against the extension's permissions. [Security model](/docs/extensions/security) explains.

Before a download starts, OrbTorrent adds it so that the engine stops it the moment its file list arrives. The checks run on that list, and OrbTorrent then starts the download, or holds it.

## Updates

OrbTorrent updates itself with [Sparkle](https://sparkle-project.org). Once a day it reads a feed from `updates.orbtorrent.com`, a Cloudflare Worker. The feed and each update are signed, and Sparkle checks both signatures before it installs anything. Updates are downloaded from GitHub Releases. After an update, **What's New** shows the release's notes, from the same feed.

## Privacy

OrbTorrent has no account, ID or crash reporting. Its update check carries a few anonymous counts, from `AnonymousCounts.swift`, which the update feed's Worker adds up. [Privacy](/docs/guides/privacy) lists everything it connects to and counts.

## The source

OrbTorrent is open source, under the GNU GPL v3 or later. The extension SDK is MIT. The [source on GitHub](https://github.com/orbtorrent/OrbTorrent) has the app, the engine's build, the extension host, the SDK, the official extensions, the update feed and this website. [Contribute](/docs/contribute) explains how to build it.
