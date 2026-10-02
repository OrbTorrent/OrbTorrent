---
title: Files on your Mac
description: Where OrbTorrent keeps your library, its settings, the download engine's files, its logs and your extensions, and what's safe to delete.
---

Everything OrbTorrent keeps is on your Mac. Your downloaded files are wherever you saved them, your **Downloads** folder unless you chose another. Everything else is in one folder:

```
~/Library/Application Support/OrbTorrent/
├── Engine/                         the download engine's own folder
│   └── qBittorrent/
│       ├── config/qBittorrent.ini  the engine's settings
│       └── data/
│           ├── BT_backup/          your library: each download's torrent and progress
│           └── logs/qbittorrent.log  the engine's log
├── engine-credentials.json         the engine's private password, readable only by you
├── engine-console.log              what the engine printed as it ran
├── trackers.txt                    the public tracker list, for finding more peers
├── Extensions/
│   ├── Installed/                  extensions you've installed
│   ├── settings.json               extensions' settings, except passwords
│   ├── checks.json                 what checks found
│   ├── Data/                       each extension's stored data
│   └── Logs/                       each extension's log
├── Logs/
│   └── When a Download Finishes.log  what your own program printed, if you chose one
└── dev.sock                        for orb, while development extensions are allowed
```

To open it, choose **Go › Go to Folder…** in Finder and enter `~/Library/Application Support/OrbTorrent`, or click **Show Data Folder in Finder** in **Settings › Engine**, which shows the `Engine` folder inside it.

## Elsewhere

| | Where |
|---|---|
| **OrbTorrent's own settings** | `~/Library/Preferences/com.orbtorrent.mac.plist` |
| **Caches, such as a downloaded update** | `~/Library/Caches/com.orbtorrent.mac` and `~/Library/HTTPStorages/com.orbtorrent.mac` |
| **The sandbox extensions run in** | `~/Library/Containers/com.orbtorrent.mac.extension-host`, which macOS makes |
| **Extension passwords and API keys** | Your login Keychain |
| **The official extensions** | Inside OrbTorrent, in `OrbTorrent.app/Contents/Resources/Extensions` |
| **Pieces of files you skipped** | A hidden `.<info hash>.parts` file in the download's folder |
| **Files extensions added,** such as subtitles | Next to the download's own files, listed in its **Checks** tab. They're moved and removed with it. |

The `.parts` file holds the pieces a skipped file shares with files you're downloading, which BitTorrent needs to check them. It goes with the download's files when you remove them too.

## Logs

- **The engine's log:** **Settings › Engine › Show Engine Log**. Report a Problem can include its recent lines, with addresses hidden.
- **An extension's log:** on its page, under **Logs**, with **Show Log File**.
- **Your own program's log,** if you chose one to [run when a download finishes](/docs/guides/run-a-program): **Settings › Downloads › Show Log**.

## What's safe to delete

- **Your downloaded files,** once you've removed their downloads from OrbTorrent.
- **The whole OrbTorrent folder,** with OrbTorrent quit, to start again from scratch. OrbTorrent forgets every download, but their files stay where they are. [Settings](/docs/reference/settings#reset-orbtorrent) explains.

Don't edit the engine's files while OrbTorrent is open: OrbTorrent manages them, and the engine rewrites them as it runs.

## OrbTorrent Dev

If you build OrbTorrent yourself, **OrbTorrent Dev** keeps its own library and settings in `~/Library/Application Support/OrbTorrent Dev`, so it can run beside OrbTorrent. [Contribute](/docs/contribute) explains.
