---
title: Magnet links and .torrent files
description: What a magnet link is, how to open one on a Mac, how to choose the app that opens them, and what to do when your browser won't.
---

A magnet link starts a download from a web page. It isn't a file: it's a short address, beginning `magnet:`, that names the download by a fingerprint of its contents. Your torrent app uses it to find people who have the download, and gets its list of files from them.

A magnet link looks like this, usually much longer:

```txt
magnet:?xt=urn:btih:0123456789abcdef0123456789abcdef01234567&dn=Big+Buck+Bunny&tr=udp%3A%2F%2Ftracker.example.org%3A1337
```

- **`xt`** is the fingerprint, called the info hash. It's the only part a magnet link needs.
- **`dn`** is the download's name, to show while its file list arrives.
- **`tr`** is a tracker, a server that introduces people sharing the download. There can be several, or none.

## Open one

Click the link in your browser. If OrbTorrent is your Mac's [default torrent app](#choose-the-app-that-opens-them), it opens in OrbTorrent, which asks which files you want and where to save them.

Your browser checks with you first:

- **Safari** asks whether to allow the page to open OrbTorrent, every time. Click **Allow**.
- **Chrome** asks whether to open OrbTorrent. Tick **Always allow** to stop it asking on that site, then click **Open OrbTorrent**.
- **Firefox** asks whether the site may open the link. Choose OrbTorrent, and tick that it should always do so.

You can also add a magnet link without clicking it:

- **Copy it,** then open OrbTorrent's menu bar panel: it offers **Add “…” from Clipboard**.
- **Paste it** into the OrbTorrent window, with <kbd class="key">⌘V</kbd>.
- **Choose File › Add Magnet Link…** (<kbd class="key">⌘U</kbd>), and paste it there.

A magnet link carries no file list, so OrbTorrent shows **Fetching Info** until someone sharing the download sends it, usually within seconds. [Your first download](/docs/get-started/first-download) explains the rest.

## Choose the app that opens them

macOS has no setting of its own for magnet links: each torrent app has a switch to make itself the default, and whichever app last used it opens them.

To make it OrbTorrent, open **Settings › General** and click **Make OrbTorrent the Default**. From then on, magnet links in your browser and `.torrent` files in Finder open in OrbTorrent. OrbTorrent also offers this when you first open it.

## If nothing happens

- **No app is set to open them.** Make OrbTorrent the default, as above, then click the link again.
- **Another app opens them,** often after you've installed or updated another torrent app. Make OrbTorrent the default again.
- **Your browser remembers saying no.** Firefox keeps your choice in **Settings › General › Applications**, next to **magnet**: set it to OrbTorrent, or **Always ask**.
- **The link doesn't start with `magnet:?`.** You may have copied only part of it. Copy the whole link again.

Whatever the browser does, you can always copy the link and add it from OrbTorrent instead.

## .torrent files

A `.torrent` file holds what a magnet link does, plus the download's file list, so it can start straight away. Some sites offer one instead of, or as well as, a magnet link.

- **Double-click it** in Finder, and it opens in your default torrent app.
- **To open it in OrbTorrent this once,** Control-click it and choose **Open With › OrbTorrent**.
- **To have every `.torrent` file open in OrbTorrent,** select one, choose **File › Get Info**, choose OrbTorrent under **Open with**, and click **Change All**.

You can also drag a `.torrent` file onto OrbTorrent's window, or choose **File › Open Torrent File…** (<kbd class="key">⌘O</kbd>). Downloading `.torrent` files saves them to your Downloads folder, where you can delete them once the download has started.

## Are they safe?

A magnet link or a `.torrent` file only describes a download. Opening one can't run anything on your Mac.

What it downloads can still be a fake, such as a "film" that's really a program. OrbTorrent's Fake Download Check looks at a download's files as soon as their list arrives, before any of them do, and holds one that looks fake until you decide. [Checks and held downloads](/docs/guides/checks) explains.
