# OrbTorrent Extensions

Extensions hook into moments in a download's life, the way checks run on a pull
request. An extension can look at a download **before it starts** and hold it
until the user decides, or act on it **after it finishes**. Its result shows in
the download's **Checks** tab in the inspector.

Extensions have their own page in OrbTorrent's main window: **Extensions**, at
the bottom of the sidebar. **Installed** shows which extensions check downloads
at each point, with each one's settings. **Activity** lists every check on
every download, and any download a check is holding. **Develop** has the switch
`orb dev` needs and the steps to build your own.

A switch at the top of **Installed** turns every extension off, for using
OrbTorrent as a plain torrent client. Nothing runs and no checks show until
it's back on, and each extension keeps its settings.

OrbTorrent ships two official extensions, built from this repository's
`extensions/` folder:

- **Fake Download Check** holds downloads that look fake, such as a film that
  contains a program.
- **VirusTotal Scan** looks up finished downloads' files on VirusTotal by their
  fingerprints.

## Guides

- [Getting started](getting-started.md): make, test and load your first extension.
- [Hooks](hooks.md): when they run, what they receive and return, and their limits.
- [API](api.md): everything `@orbtorrent/api` provides.
- [Manifest](manifest.md): every field of `package.json`.
- [Testing](testing.md): tests that run without OrbTorrent.
- [Sharing](sharing.md): `.orbext` files, and adding an official extension.
- [Security](security.md): the sandbox, permissions, and what OrbTorrent enforces.

For coding agents, every new extension has an `AGENTS.md` with the same
information in one file, and there's an Agent Skill in
[`skills/build-orbtorrent-extension`](../../skills/build-orbtorrent-extension).
[`llms.txt`](llms.txt) and [`llms-full.txt`](llms-full.txt) hold these docs for
language models.
