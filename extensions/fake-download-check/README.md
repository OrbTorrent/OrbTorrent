# Fake Download Check

An official OrbTorrent extension. Before a download starts, it looks at the
names and sizes of its files for signs that it's fake, and holds it until you
decide when it finds one. It sends nothing anywhere.

It first works out what a download is: a video, music or a book from what most
of its size is, and otherwise from its name, since a fake film often has no
video at all. Names with a version number or words such as "for Mac" are
software. Software, games and courses carry programs for good reason, so
programs only count in films, episodes, music and books.

## What it holds

- A file with a double extension that ends in a program or shortcut, such as
  `Film.mp4.exe` or `Atomic Habits.epub.exe`, or a Mac app named like
  `Sunset.jpg.app`. Spaces or invisible characters between the two don't hide
  it, and nor does a right-to-left character that makes a name read backwards.
  This applies to any download.
- A film, episode, album or book that includes a program: a Windows program,
  script or shortcut, or a Mac app, installer, AppleScript or screensaver. A
  film, an album or a book never needs one. Two exceptions: the 99-byte
  `RARBG_DO_NOT_MIRROR.exe` that RARBG put in its releases, which is text, and
  the Java menus on a whole Blu-ray disc.
- A film or episode that's an archive with a file about a password: the video is
  locked, and the password is sold or hidden elsewhere. A scene release's own
  `.nfo` doesn't count, even for a film called *Passengers* or *Key Largo*.

## What it warns about

The download still starts for these; they get a badge so you can take a look.

- A film far too small for the quality its name claims (under 150 MB at 720p,
  300 MB at 1080p, or 1 GB at 2160p), or under 100 MB when it claims none.
  Episodes, samples and trailers are left out.
- A film from a year that hasn't come yet.
- Only `.wmv` or `.asf` video: the classic "codec required" fake.
- Link files whose names say to download or watch elsewhere.
- A film-like name with no video, or with its video inside an archive. From a
  private tracker, an archive is expected: that's how scene releases come.
- A course that includes a program, which it warns about rather than holds,
  since courses often include the software they teach.

## What it can't see

Names and sizes can't show a fake whose names and sizes look right, such as a
"film" that's really a different video. VirusTotal Scan checks files once they
arrive.

## Develop

```sh
npm test   # every rule has tests, and so do real releases that must pass
```
