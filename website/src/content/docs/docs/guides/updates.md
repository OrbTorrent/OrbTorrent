---
title: Updates
description: How OrbTorrent keeps itself up to date with signed updates, the settings for checking and installing, and where to see what's new.
---

OrbTorrent updates itself. Each update is signed, so your Mac only installs one that came from OrbTorrent.

## How it works

- **Once a day,** OrbTorrent checks for a new version, while **Check for updates automatically** is on.
- **If one's found while you're using OrbTorrent,** a window offers it, with its release notes. Install it now, be reminded later, or skip that version.
- **If one's found while OrbTorrent is in the background,** it waits quietly instead: in the menu bar panel, at the top of the window, and in a notification, until you look at it.
- **After an update,** **What's New** shows what changed in the version you just installed, and in any you skipped.

To check now, choose **OrbTorrent › Check for Updates…**, or **More (…) › Check for Updates…** in the menu bar panel, or click **Check Now** in **Settings › General**.

## Settings

In **Settings › General › Updates**:

| Setting | |
|---|---|
| **Check for updates automatically** | Checks once a day. |
| **Download and install updates automatically** | Downloads each update as it's found, and installs it the next time OrbTorrent quits. |

The section also shows your version, and when OrbTorrent last checked.

## What's new

Choose **Help › What's New in OrbTorrent** to see the notes for the version you have, with **View on GitHub** for the full release. Every release, with its notes and its disk image, is on [GitHub Releases](https://github.com/sanjevirau/OrbTorrent/releases).

## What a check sends

A check for updates goes to `updates.orbtorrent.com`. It sends OrbTorrent's version and build number, which is how we count the Macs on each version, and nothing else. The address a check comes from isn't kept. An update you install is downloaded from GitHub.

Turn off **Check for updates automatically** and OrbTorrent never checks unless you ask. [Privacy](/docs/guides/privacy) lists everything OrbTorrent connects to.
