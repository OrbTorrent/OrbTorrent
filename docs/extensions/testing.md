# Testing

`orb test` runs every JSON file in `tests/` against the built hook, without
OrbTorrent. It runs the hook in a Node.js `vm` context set up like OrbTorrent's
extension host: no Node.js APIs, and every request answered from the test's
mocks. The rules and error messages match OrbTorrent's.

```json
{
  "name": "Fails a program that 12 engines flag",
  "hook": "scan",
  "preferences": { "apiKey": "test-key" },
  "download": {
    "name": "Tool 2.0",
    "files": [{ "path": "Tool 2.0/setup.exe", "size": 5000000, "sha256": "aaa…" }]
  },
  "storage": {},
  "mocks": {
    "fetch": [
      { "url": "https://www.virustotal.com/api/v3/files/*", "status": 429, "times": 1 },
      { "url": "https://www.virustotal.com/api/v3/files/*", "json": { "data": {} } }
    ]
  },
  "expect": { "status": "failed", "summaryIncludes": "12 of 70 engines" }
}
```

## Fields

| Field | Meaning |
|---|---|
| `hook` | The hook to run. Leave it out when there's only one. |
| `verify` | `true` runs the settings check with `preferences` instead. |
| `download` | `name`, `isPrivate` and `files` (`path`, `size`, `wanted`, and `sha256` for `files.sha256`). |
| `preferences` | Settings. Missing ones take their defaults. |
| `storage` | What `storage` holds before the run. |
| `mocks.fetch` | `{ url, method?, status?, json?, text?, headers?, times? }`. `*` in `url` matches any text. `times` answers that many requests before the next matching mock takes over. |
| `timeout` | Milliseconds, 10 000 unless set. |

## Expectations

| Key | Passes when |
|---|---|
| `status` | The result's status matches. |
| `summaryIncludes` | The summary includes the text, ignoring case. |
| `summaryMatches` | The summary matches the regular expression. |
| `detailsIncludes` | The details include the text. |
| `fetched` | Each URL (with `*`) was requested. |
| `throws` | The hook threw an error including the text. |
| `ok`, `messageIncludes` | For `verify`. |
| `not` | The expectation inside it fails. |

## Time

Timers run on a virtual clock: `setTimeout` and `sleep` fire as soon as nothing
else is pending, and `Date.now()` moves forward by the time waited. A hook that
waits 15 seconds between requests for a rate limit is tested in moments.

## The real thing

Node's JavaScript engine isn't JavaScriptCore, so rare differences are possible.
`orb run <hook> --download "<name>"` runs the hook in OrbTorrent itself.
