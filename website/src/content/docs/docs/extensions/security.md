---
title: Security model
description: How OrbTorrent runs extensions in a sandbox, what each one can and can't reach, how it keeps secrets, and how the development connection is protected.
---

Extensions are code from someone else, running on your Mac. OrbTorrent limits what that code can do, rather than relying on anyone reviewing it.

## What an extension can do

Exactly what its `package.json` says, which users see before they install it:

| An extension can | When |
|---|---|
| See the names and sizes of the files in your downloads | Always |
| Hold a download before it starts, until you decide | With a `beforeStart` hook |
| See what other extensions found in your downloads | With an `afterChecks` hook |
| Read the contents of your downloads | With `"files": "contents"` |
| Add files, such as subtitles, next to your downloads | With `"files": "add"` |
| Connect to a site | For each host in `permissions.network` |

OrbTorrent enforces the list. An extension can't read other files, change or delete any, reach other sites, or see anything else. It can't run programs either: [running one of your own](/docs/guides/run-a-program) is a setting only you can choose.

## What it never sees

- **Where your downloads are saved.** Paths are relative to each download's folder.
- **Your downloads' trackers,** which can carry a private tracker's personal key.
- **Your other downloads,** only the one it's checking.
- **Other extensions' settings and storage,** only its own. Only an `afterChecks` hook sees their results on the download it's reporting on.
- **Your IP address, your library, or OrbTorrent's settings.**

## The extension host

- **A fresh process for every run.** Each hook runs in its own `orb-extension-host` process, which exits when the hook returns. Nothing carries over except through `storage`.
- **A strict macOS sandbox.** The helper has the App Sandbox entitlement and nothing else. It can't read or write files, connect to the network, or even look up a host name, and any program it started would inherit the same sandbox.
- **Everything goes through OrbTorrent.** Every request, file fingerprint, upload and storage write goes to OrbTorrent as a message, and OrbTorrent checks it against the extension's permissions first.
- **Limits.** OrbTorrent enforces time, CPU and memory limits, and stops a helper that goes over them. A `beforeStart` check that doesn't finish lets the download start, so a broken extension never blocks downloads.
- **JIT, only in the helper.** JavaScriptCore's JIT compiler is on in the sandboxed helper, not in OrbTorrent itself.

## The network

- HTTPS only, on port 443, to hosts listed exactly in `permissions.network`.
- Redirects are followed only to hosts on the same list.
- A host that resolves to an address on the Mac or a local network is refused, so an extension can't reach your router, your NAS or OrbTorrent's own engine. OrbTorrent connects to the very address it checked, through a relay of its own, so a host can't pass the check and then switch to a local address.
- There are no cookies and no shared cache.
- Responses are limited to 10 MB, and each request to 30 seconds.

## Files

With `"files": "contents"`, an extension can ask for a finished file's SHA-256 fingerprint, or upload it with `fetch`. OrbTorrent reads the file itself and streams it, so the extension never gets a path, and never reads anything that isn't part of the download it's checking.

## Adding files

With `"files": "add"`, an extension can add a file next to one of a finished download's files. OrbTorrent writes it, after checking that:

- it's next to a file of the download the extension is running on, in the same folder, and named after that file, so nothing lands anywhere else;
- it's subtitles, text, an image or checksums, never a program, a script or an app;
- nothing's there already, not even a link, unless the same hook added it to the same download before;
- it's no more than 10 MB, and the run has added no more than 200 files and 50 MB.

Each file is readable but never runnable, and marked as downloaded from the internet, as browsers do. The Checks tab lists every file an extension added, and they're moved and removed with their download.

## Settings and secrets

- **Passwords go in the Keychain.** `password` settings are stored in the macOS Keychain, not in a file.
- **An extension sees only its own settings.**
- **Secrets are hidden in logs.** OrbTorrent replaces them wherever they'd appear.
- **Removing an extension deletes its settings and storage,** passwords included.

## Installing

- **The install sheet comes first.** Nothing is installed until the user has seen what the extension can do and confirmed it.
- **Updates show what's new.** A new permission is marked **New** on the update's install sheet.
- **Extensions from anyone but OrbTorrent are marked "Not reviewed by OrbTorrent".** The limits above apply to every extension, reviewed or not.
- **Official names are reserved.** An installed extension can't take an official extension's name.

## Development

`orb dev` and `orb run` reach OrbTorrent through a socket at `~/Library/Application Support/OrbTorrent/dev.sock`:

- only your account can open it: it's mode 0600, and the connecting process's user is checked;
- it's only there while **Allow development extensions** is on;
- OrbTorrent asks the first time each folder is loaded, and remembers the folders you allow;
- installing still needs you to confirm the install sheet.

A coding agent working for you can build, test and run an extension, but can't turn on development extensions, allow its folder, or install anything without you.

## Turning it all off

One switch, **Check downloads with extensions** on the Extensions page, turns every extension off. Nothing runs until it's back on.

## Report a security problem

Please report security problems privately, by email to `help@orbtorrent.com` with "Security" in the subject, not in a public issue. [Report a problem](/docs/help/report-a-problem#security-problems) explains.
