---
title: Uninstall OrbTorrent
description: Remove OrbTorrent from your Mac, with or without its library and settings. Your downloaded files stay where they are.
---

## Remove the app

1. Quit OrbTorrent: click **More (…)** in the menu bar panel, then **Quit OrbTorrent**.
2. Drag **OrbTorrent** from your Applications folder to the Trash.

Your downloaded files stay where they are. So do your library and settings, in case you install OrbTorrent again.

## Remove everything else too

To leave nothing behind, also delete:

| | Where |
|---|---|
| **Your library, the engine's files, logs and extensions** | `~/Library/Application Support/OrbTorrent` |
| **OrbTorrent's settings** | `~/Library/Preferences/com.orbtorrent.mac.plist` |
| **Caches, such as a downloaded update** | `~/Library/Caches/com.orbtorrent.mac` and `~/Library/HTTPStorages/com.orbtorrent.mac` |
| **The sandbox extensions run in** | `~/Library/Containers/com.orbtorrent.mac.extension-host` and `~/Library/Application Scripts/com.orbtorrent.mac.extension-host` |
| **Extension passwords and API keys** | In **Keychain Access**, search for "OrbTorrent" |

To get to the folders, choose **Go › Go to Folder…** in Finder and paste the path.

If you'd made OrbTorrent your default torrent app, choose another in its own settings, and remove OrbTorrent from **System Settings › General › Login Items & Extensions** if it's still listed.

## With Homebrew

If you installed OrbTorrent with Homebrew, uninstall it with Homebrew too:

```sh
brew uninstall orbtorrent
```

To remove everything else as well, add `--zap`: `brew uninstall --zap orbtorrent` deletes everything in the table above, except the passwords in your Keychain.

## Your downloads

Uninstalling never touches your downloaded files. To remove those as well, delete them in Finder, or remove each download in OrbTorrent with **Remove and Move Files to Trash** before you uninstall.

## Coming back

Reinstall OrbTorrent from [the download page](/download). If you left its folder, your downloads and settings are just as they were. If you removed it, OrbTorrent starts as new, and can bring your downloads back from Transmission or qBittorrent if they're still there.
