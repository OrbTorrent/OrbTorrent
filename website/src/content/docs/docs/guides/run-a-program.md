---
title: Run a program when a download finishes
description: Have OrbTorrent run a script or program of your own when each download finishes, such as one that unpacks it or copies it to another drive.
---

OrbTorrent can run a program or script of your own each time a download finishes: to unpack it, copy it to another drive, tell your media server, or anything else you can write a script for. It's for what [extensions](/docs/extensions) can't do, such as reaching your local network or changing files.

## Set it up

1. Open **Settings › Downloads**.
2. Under **When a Download Finishes**, click **Choose…** next to **Run**, and choose your script or program.

A script needs a first line that says what runs it, such as `#!/bin/zsh`, and must be allowed to run. If OrbTorrent says it can't be run, open Terminal and enter `chmod +x` and the script's path. An app works too, such as one made with Automator.

To stop, click **Stop Running It**.

## What it gets

The download's file or folder is the first argument, `$1`, and its details are in the environment:

| Variable | What it holds | Such as |
|---|---|---|
| `ORB_PATH` | The download's file or folder, the same as `$1` | `/Users/you/Downloads/Film (2024)` |
| `ORB_FOLDER` | The folder it's saved in | `/Users/you/Downloads` |
| `ORB_NAME` | Its name | `Film (2024)` |
| `ORB_HASH` | Its info hash | `0123456789abcdef0123456789abcdef01234567` |
| `ORB_SIZE` | The size of the files you chose, in bytes | `4200000000` |
| `ORB_PRIVATE` | Whether it's from a private tracker | `true` or `false` |

It starts in the folder the download is saved in. Homebrew's folders, `/opt/homebrew/bin` and `/usr/local/bin`, are on its `PATH`, so the command-line tools you've installed are found.

## When it runs

- **Once a download finishes** while OrbTorrent is open, and after the download's [checks](/docs/guides/checks) that run once it finishes, so it sees any subtitles an extension added.
- **Not if one of those checks failed,** such as VirusTotal finding malware. The log says which check, and why.
- **One at a time,** in the order downloads finish.
- **For up to an hour.** A program still running then is stopped.

## What it printed

Everything it prints, and when each run started and how it ended, goes in a log: click **Show Log** in **Settings › Downloads**, or open `~/Library/Application Support/OrbTorrent/Logs/When a Download Finishes.log`. It keeps 1 MB, and the 1 MB before that.

## Examples

### Unpack archives

Releases that come as RAR archives, unpacked next to them with [unar](https://theunarchiver.com/command-line), which you can install with `brew install unar`:

```zsh title="unpack.sh"
#!/bin/zsh
# Unpacks the RAR archives in a finished download, next to each one.
# A download that's a single file has nothing to unpack.
[[ -d "$ORB_PATH" ]] || exit 0
cd "$ORB_PATH"
for archive in **/*.rar(N); do
  # A set of parts unpacks from its first.
  [[ "$archive" == *.part<2->.rar ]] && continue
  unar -quiet -force-skip -output-directory "${archive:h}" "$archive"
done
```

The archives stay where they are, so OrbTorrent can go on sharing them.

### Copy it to another drive

```zsh title="copy.sh"
#!/bin/zsh
# Copies each finished download to a media drive, if it's connected.
destination="/Volumes/Media/Downloads"
[[ -d "$destination" ]] || exit 0
rsync -a "$ORB_PATH" "$destination/"
```

Copy rather than move: OrbTorrent shares a download from where it saved it. To move a download, use **Move To…** in OrbTorrent, which takes its files and anything extensions added along.

### Tell Plex

```zsh title="plex.sh"
#!/bin/zsh
# Asks Plex, on this Mac, to scan its library for what just arrived.
# The library's number is in its address in Plex Web, after "source=".
curl -fsS "http://127.0.0.1:32400/library/sections/1/refresh?X-Plex-Token=YOUR_TOKEN"
```

Plex's help explains [finding your token](https://support.plex.tv/articles/204059436-finding-an-authentication-token-x-plex-token/).

## Keep it safe

- **It runs as you,** with access to your files, like any program you open. Only run a script you've written or read.
- **Only you can choose it,** here in Settings. Extensions, the `orb` tool and the download engine can't set it or change it. The engine's own way of running programs is always off.
- **A download's name can't run a command.** OrbTorrent starts your program directly, not through a shell, so a name with quotes or `;` in it is only text. Keep it that way in your script: put variables in double quotes, such as `"$ORB_PATH"`.
- **macOS may ask** whether OrbTorrent can use a folder your program uses, such as **Documents** or an external drive, since it runs on OrbTorrent's behalf.
