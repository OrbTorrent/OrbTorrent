---
title: Updates
description: How OrbTorrent keeps itself up to date with signed updates, installed while you aren't using it, the settings for checking and installing, and what's new.
---

OrbTorrent updates itself. Each update is signed, so your Mac only installs one that came from OrbTorrent.

## How it works

- **Once a day,** OrbTorrent checks for a new version, while **Check for updates automatically** is on.
- **A new version downloads in the background,** and OrbTorrent restarts to install it once you're not using it: once it's not in front, or no one has touched the Mac for a couple of minutes, and nothing would be cut short, such as files being moved or checked. It comes back in the menu bar, and your downloads carry on where they left off.
- **If you're using OrbTorrent when it's ready,** the menu bar panel and the window say so, with **Restart to Update** to install it then.
- **After an update,** **What's New** shows what changed in the version you just installed, and in any you skipped, the next time you open the window.

With **Download and install updates automatically** off, a window offers each update instead, with its release notes: install it now, be reminded later, or skip that version. One found while OrbTorrent is in the background waits quietly, in the menu bar panel, at the top of the window and in a notification, until you look at it. A fix for a version with a serious problem is shown straight away, and can't be skipped.

To check now, choose **OrbTorrent › Check for Updates…**, or **More (…) › Check for Updates…** in the menu bar panel, or click **Check Now** in **Settings › General**.

## Settings

In **Settings › General › Updates**:

| Setting | |
|---|---|
| **Check for updates automatically** | Checks once a day. |
| **Download and install updates automatically** | Downloads each update as it's found, and restarts OrbTorrent to install it while you're not using it. On unless you turn it off. |

The section also shows your version, and when OrbTorrent last checked.

## What's new

Choose **Help › What's New in OrbTorrent** to see the notes for the version you have, with **View on GitHub** for the full release. Every release, with its notes and its disk image, is on [GitHub Releases](https://github.com/orbtorrent/OrbTorrent/releases).

## What a check sends

A check for updates goes to `updates.orbtorrent.com`. It says which version of OrbTorrent it is, with a few anonymous counts: your version of macOS, the kind of Mac, the week OrbTorrent was installed and how often it quit unexpectedly. None of them is an ID, or says how you use OrbTorrent. **Settings › General › See What's Sent** shows exactly what the next check sends, and [Privacy](/docs/guides/privacy#what-orbtorrent-counts) explains each. The address a check comes from isn't kept. An update you install is downloaded from GitHub.

Turn off **Check for updates automatically** and OrbTorrent never checks unless you ask. [Privacy](/docs/guides/privacy) lists everything OrbTorrent connects to.
