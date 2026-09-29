# VirusTotal Scan

An official OrbTorrent extension. When a download finishes, it looks up each
file's fingerprint (SHA-256) on [VirusTotal](https://www.virustotal.com), which
checks it against about 70 antivirus engines. Nothing is uploaded unless you
turn that on.

- **Failed** when 3 or more engines call a file malicious.
- **Warning** when 1 or 2 do, or any calls it suspicious: single-engine false
  alarms are common.
- **Passed** otherwise. Files VirusTotal has never seen are listed in the
  details, not warned about: new releases often haven't been seen yet.

It checks programs first, then archives, then documents. By default it checks
only those; set **Files to check** to **All files** to include videos and music.
The free key allows 4 lookups a minute, so it waits between them, and it
remembers answers for a week so running it again doesn't use up your limit.

## Develop

```sh
npm test   # the tests answer VirusTotal's API from mocks, with a virtual clock
```
