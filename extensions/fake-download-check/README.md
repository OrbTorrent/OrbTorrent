# Fake Download Check

An official OrbTorrent extension. Before a download starts, it looks at the
names and sizes of its files for signs that it's fake, and holds it until you
decide when it finds one. It sends nothing anywhere.

## What it holds

- A file with a double extension that ends in a program or shortcut, such as
  `Film.mp4.exe`, or a name that hides its real extension with a right-to-left
  character. This applies to any download.
- A film or episode that includes a Windows program, script or shortcut, or a
  Mac program or installer. A video doesn't need a program to play.
- A film or episode that's an archive with a file about a password: the video is
  locked, and the password is sold or hidden elsewhere.

## What it warns about

The download still starts for these; they get a badge so you can take a look.

- A film far too small for the quality its name claims: under 300 MB at 1080p,
  or under 1 GB at 2160p.
- Only `.wmv` or `.asf` video: the classic "codec required" fake.
- Link files whose names say to download or watch elsewhere.
- A film-like name with no video, or with its video inside an archive.

## Develop

```sh
npm test   # every rule has tests, including releases that must pass
```
