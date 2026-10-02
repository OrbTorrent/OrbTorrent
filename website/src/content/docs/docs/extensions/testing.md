---
title: Testing
description: Write JSON tests that run an extension's hooks without OrbTorrent, with the network mocked, file fingerprints and storage set up, and time on a virtual clock.
---

`orb test` runs every JSON file in `tests/` against your built hooks, without OrbTorrent. Each test is a download, the network's answers, and what the hook should return.

```sh
npm test
```

```txt title="Output"
✓ Holds a download with a screensaver in it tests/holds-a-screensaver.json
✓ Ignores a screensaver the user isn't downloading tests/ignores-a-skipped-screensaver.json
✓ Lets a film without one start tests/lets-a-film-start.json

3 passed
```

To run some tests only, name them: `npx orb test tests/holds-a-screensaver.json`.

## A test

```json title="tests/fails-a-program-many-engines-flag.json"
{
  "name": "Fails a program that 12 engines flag",
  "hook": "scan",
  "preferences": { "apiKey": "test-key" },
  "download": {
    "name": "Tool 2.0",
    "files": [{ "path": "Tool 2.0/setup.exe", "size": 5000000, "sha256": "aaaa…" }]
  },
  "mocks": {
    "fetch": [
      {
        "url": "https://www.virustotal.com/api/v3/files/*",
        "json": { "data": { "attributes": { "last_analysis_stats": { "malicious": 12, "suspicious": 0, "undetected": 58, "harmless": 0 } } } }
      }
    ]
  },
  "expect": { "status": "failed", "summaryIncludes": "12 of 70 engines" }
}
```

[Test files](/docs/extensions/reference/tests) lists every field. The ones you'll use most:

- **`download`**: its `name` and `files`, each with a `path`, a `size`, and `"wanted": false` for a file the user skipped.
- **`preferences`**: the settings. Any you leave out take their defaults.
- **`expect`**: what the result should be.

## What to test

- **Each thing it catches,** with the summary you expect.
- **What must pass.** Releases that look like what you catch, but aren't, matter most: a false alarm that holds a download is worse than a missed warning. The Fake Download Check tests real releases that must pass, as well as each fake it holds.
- **What it skips,** such as files the user didn't want, and when a setting is empty.
- **Failure:** a refused API key, a rate limit, a server error. Before a download starts, each should be `skipped`.

## Mock the network

Requests are answered from `mocks.fetch`, never the real network:

```json
{
  "mocks": {
    "fetch": [
      { "url": "https://www.virustotal.com/api/v3/files/aaaa…", "status": 429, "times": 1, "json": { "error": { "code": "QuotaExceededError" } } },
      { "url": "https://www.virustotal.com/api/v3/files/aaaa…", "json": { "data": { "attributes": { "last_analysis_stats": { "malicious": 0, "suspicious": 0, "undetected": 60, "harmless": 10 } } } } }
    ]
  }
}
```

- **A request takes the first mock that matches** its `method` (`GET` unless you say) and `url`.
- **`*` in a `url` matches any text,** such as `https://www.virustotal.com/api/v3/files/*`.
- **`times`** answers that many requests, then the next matching mock takes over: here, a rate limit, then success.
- **`json`** answers with JSON, and sets `content-type: application/json`. **`text`** answers with text. **`status`** is 200 unless you say, and **`headers`** adds headers.
- **A request with no mock fails the test,** and says which: "The test has no mock for GET https://…. Add one to "mocks": { "fetch": [...] }."

The rules OrbTorrent applies run in tests too: a host missing from `permissions.network`, or a plain `http://` address, is refused with the same error.

`"fetched"` in `expect` checks that a request was made, and `"not": { "fetched": […] }` that one wasn't.

## Files and storage

- **`files.sha256`** returns each file's `sha256` from the test. A file without one fails the test, saying so.
- **`storage`** sets what the extension's storage holds before the run, to test that it uses what it kept:

```json
{
  "storage": {
    "lookups": { "aaaa…": { "at": 9999999999999, "stats": { "malicious": 0, "suspicious": 0, "total": 70 } } }
  },
  "expect": { "status": "passed", "not": { "fetched": ["https://www.virustotal.com/api/v3/files/aaaa…"] } }
}
```

Reading files follows OrbTorrent's rules too: without `"files": "contents"`, or in a `beforeStart` hook, it's refused.

## Time

Timers run on a **virtual clock**. `setTimeout` and `sleep` fire as soon as nothing else is pending, and `Date.now()` moves on by the time waited. A hook that waits 15 seconds between requests for a rate limit is tested in moments, and a test of a minute's back-off takes no time at all.

Each test can run for 10 seconds of real time, unless it sets `timeout` in milliseconds.

## Test verify

To test the settings check, set `"verify": true` and the `preferences` to check, and expect `ok` and part of the `message`:

```json title="tests/verify-refuses-a-bad-topic.json"
{
  "name": "Verify refuses a topic with spaces",
  "verify": true,
  "preferences": { "topic": "my downloads" },
  "expect": { "ok": false, "messageIncludes": "letters, digits" }
}
```

## Expectations

| Key | Passes when |
|---|---|
| `status` | The result's status matches. |
| `summaryIncludes` | The summary includes the text, ignoring case. |
| `summaryMatches` | The summary matches the regular expression. |
| `detailsIncludes` | The details include the text. |
| `fetched` | Each URL was requested. `*` matches any text. |
| `throws` | The hook threw an error including the text. |
| `ok` and `messageIncludes` | For `verify`: whether it accepted the settings, and its message. |
| `not` | The expectation inside it fails. |

A test with no `expect` passes if the hook returns without throwing.

## How tests run

`orb test` builds the extension, then runs each hook in a Node.js `vm` context set up like OrbTorrent's extension host: no Node.js APIs, and every request, fingerprint and storage call answered by the test. The rules and error messages are OrbTorrent's own.

Node's JavaScript engine isn't JavaScriptCore, which OrbTorrent uses, so rare differences are possible. To be sure, run a hook in OrbTorrent itself on a real download with [`orb run`](/docs/extensions/debugging#run-a-hook-on-a-download).

## For scripts and agents

`npx orb test --json` prints the results as one JSON object, and exits with 1 if any test failed:

```json
{
  "ok": false,
  "passed": 2,
  "failed": 1,
  "tests": [
    {
      "file": "tests/lets-a-film-start.json",
      "name": "Lets a film without one start",
      "passed": false,
      "failures": ["expected status “failed”, got “passed” (No screensavers)"],
      "result": { "status": "passed", "summary": "No screensavers" },
      "logs": [],
      "fetched": []
    }
  ]
}
```

## In continuous integration

Tests, the build and the linter all run without OrbTorrent or a Mac, so they suit any CI. On GitHub Actions:

```yaml title=".github/workflows/test.yml"
name: Test
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: 22
      - run: npm ci
      - run: npx orb test
      - run: npx orb lint
      - run: npx orb build
```
