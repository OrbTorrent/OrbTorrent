---
title: Test files
description: Every field of an orb test file, and every expectation it can check.
---

A test is a JSON file in an extension's `tests/` folder. `orb test` runs them all, in name order. [Testing](/docs/extensions/testing) explains how to use them.

```json title="tests/stops-at-the-daily-limit.json"
{
  "name": "Stops at the daily limit and says how far it got",
  "preferences": { "apiKey": "test-key" },
  "download": {
    "name": "Pack",
    "files": [
      { "path": "Pack/setup.exe", "size": 5000000, "sha256": "aaaa…" },
      { "path": "Pack/extras.zip", "size": 9000000, "sha256": "bbbb…" }
    ]
  },
  "mocks": {
    "fetch": [
      { "url": "https://www.virustotal.com/api/v3/files/aaaa…", "json": { "data": { "attributes": { "last_analysis_stats": { "malicious": 0, "suspicious": 0, "undetected": 60, "harmless": 10 } } } } },
      { "url": "https://www.virustotal.com/api/v3/files/bbbb…", "status": 429, "json": { "error": { "code": "QuotaExceededError" } } }
    ]
  },
  "expect": { "status": "skipped", "summaryIncludes": "Checked 1 of 2 files, then VirusTotal's daily limit was reached" }
}
```

## Fields

| Field | Default | Meaning |
|---|---|---|
| `name` | The file's name | What the test checks, shown when it runs. |
| `hook` | The only hook | The hook to run. Needed when the extension has more than one. |
| `verify` | `false` | `true` runs the settings check, `verify`, with `preferences`, instead of a hook. |
| `download` | | The download the hook gets. See below. |
| `preferences` | The defaults | Settings. Any left out take their defaults. |
| `storage` | `{}` | What the extension's storage holds before the run. |
| `mocks.fetch` | `[]` | Answers to the hook's requests. See below. |
| `timeout` | `10000` | Milliseconds of real time the test may take. |
| `expect` | | What the result should be. Without it, the test passes if the hook doesn't throw. |

## download

| Field | Default | Meaning |
|---|---|---|
| `name` | `"Download"` | The download's name. |
| `id` | A made-up info hash | Its info hash. |
| `isPrivate` | `false` | Whether it's from a private tracker. |
| `files` | `[]` | Its files, in order: each `path`, `size` (0 unless given), `wanted` (true unless given), and `sha256`, which `files.sha256` returns for it. |

The download's `size` is the sum of its wanted files' sizes. Each file's `index` is its place in the list, from 0.

## mocks.fetch

Each mock answers requests that match it:

| Field | Default | Meaning |
|---|---|---|
| `url` | | The address to match. `*` matches any text. |
| `method` | `GET` | The method to match. |
| `status` | `200` | The status to answer with. |
| `json` | | A body to answer with, as JSON. Sets `content-type: application/json`. |
| `text` | `""` | A body to answer with, as text. |
| `headers` | | Headers to answer with. |
| `times` | Any number | How many requests this mock answers. After that, the next matching mock takes over. |

A request takes the first mock that matches. A request with no mock throws, and the test says which request needs one.

## expect

| Key | Passes when |
|---|---|
| `status` | The result's status is this. |
| `summaryIncludes` | The summary includes this text, ignoring case. |
| `summaryMatches` | The summary matches this regular expression. |
| `detailsIncludes` | The details include this text. |
| `fetched` | Each of these URLs was requested. `*` matches any text. |
| `throws` | The hook threw an error that includes this text. The rest of `expect` is then ignored. |
| `ok` | For `verify`: whether it accepted the settings. |
| `messageIncludes` | For `verify`: its message includes this text. |
| `not` | The expectation inside it doesn't pass, such as `{ "not": { "fetched": ["https://…"] } }`. |
