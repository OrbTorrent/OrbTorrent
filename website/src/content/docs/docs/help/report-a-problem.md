---
title: Report a problem
description: Send a problem report from OrbTorrent with the details that help, open an issue on GitHub, or report a security problem privately.
---

If something's wrong, tell us. Reports go to a person, who reads every one.

## From OrbTorrent

Choose **Help › Report a Problem…**, or **More (…) › Report a Problem…** in the menu bar panel.

1. **Say what happened:** what you were doing, what you expected, and what happened instead. The first line becomes the subject.
2. **Choose what's sent with it.** The report always includes the versions of OrbTorrent, macOS and the download engine, and your Mac's model. Tick **Include the engine's recent log** to add its last 60 lines, which often show what went wrong.
3. **Open in Mail.** The report opens in your own mail app, addressed to `help@orbtorrent.com`. Read it, then send it, or don't.

Nothing is sent until you send it yourself. If your mail app doesn't open, click **Copy Report** and email it to `help@orbtorrent.com` from wherever you like.

:::note[What the log shows]
In the engine's log, IP addresses and your user name are hidden. It can name your downloads, so read it before you send it.
:::

## On GitHub

You can also [open an issue](https://github.com/sanjevirau/OrbTorrent/issues/new/choose) with the bug report form. Copy the versions from **Report a Problem** or **About OrbTorrent**, so we know what you're running.

Before you do, search the [existing issues](https://github.com/sanjevirau/OrbTorrent/issues): someone may have found it already, and you can add what you've seen.

## Suggest a feature

Check the [roadmap](https://github.com/sanjevirau/OrbTorrent/blob/main/ROADMAP.md) first. It lists what's planned, what's been decided against, and why. Then open an issue with the feature request form. Many ideas fit better as an [extension](/docs/extensions), which anyone can build.

## Security problems

Don't report security problems in a public issue. Email `help@orbtorrent.com` with "Security" in the subject, and say what the problem is, how to reproduce it, and which versions of OrbTorrent and macOS you saw it on. A fix comes through OrbTorrent's automatic updates as soon as it's ready. Tell us if you'd like to be credited in the release notes.

This covers the app, its download engine, the extension host, the official extensions, the extension SDK on npm, and the update feed. Only the newest version of OrbTorrent gets security fixes.

## What helps

- **Steps to make it happen again,** if you can find them.
- **What you expected,** and what happened instead.
- **A screenshot,** for anything you can see. Leave out other people's IP addresses, and anything you'd rather not share.
- **The engine's log,** for problems with downloads.
- **For an extension,** which one, and what its **Logs** say on its page.
