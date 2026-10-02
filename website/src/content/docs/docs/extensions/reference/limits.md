---
title: Limits
description: Every limit OrbTorrent puts on an extension, in one place, from time and memory to request sizes and result lengths.
---

OrbTorrent enforces these limits, and stops a hook that goes over one. A hook that's stopped shows **Didn't finish**, with which limit it hit. Before a download starts, that lets the download start.

## Time, CPU and memory

| | Time | CPU time | Memory |
|---|---|---|---|
| `beforeStart` hook | 15 s | 10 s | 512 MB |
| `afterFinish` hook | 6 h | 2 min | 512 MB |
| `verify` | 15 s | 10 s | 512 MB |

**CPU time** is time spent computing. Waiting, for a response or with `sleep`, doesn't count, and nor does `files.sha256`, which OrbTorrent computes itself. That's how an `afterFinish` hook can pace itself for a rate limit for hours with 2 minutes of CPU time.

## Running together

- **Before a download starts,** every extension's `beforeStart` hooks run at the same time.
- **After a download finishes,** each extension's `afterFinish` runs go one at a time, and up to 4 hooks run at once across all extensions.

## Network

| | |
|---|---|
| Addresses | `https://` only, on port 443, to hosts in `permissions.network` |
| Methods | `GET`, `HEAD`, `POST`, `PUT`, `PATCH` and `DELETE` |
| Response size | 10 MB |
| Each request | 30 s |
| Redirects | Followed only to listed hosts |
| Local addresses | Refused: the Mac and its local network, checked again as it connects |
| Bodies | Text, JSON or bytes |

## Adding files

| | |
|---|---|
| When | `afterFinish` hooks, next to a file the user chose to download |
| Kinds | Subtitles, text, images and checksums, by extension |
| A file | 10 MB |
| A run | 200 files and 50 MB |
| A suffix | 64 characters, starting with `.`, `-`, `_` or a space |
| Replacing | Only a file the same hook added to the same download before |

## Storage

| | |
|---|---|
| All of an extension's storage | 1 MB of JSON |
| A key | 200 characters |

## What a hook returns

| | |
|---|---|
| `summary` | 300 characters, on one line |
| `details` | 20,000 characters |
| `link.title` | 60 characters |
| `link.url` | `https://` or `http://` |
| A `progress` message | 200 characters |
| A log entry | 10,000 characters |

Longer text is cut, not refused.

## The manifest

| | |
|---|---|
| `name`, hook names, `verify` | 64 characters, of lowercase letters, digits and hyphens |
| A host in `permissions.network` | 253 characters |

## In tests

Each test may take 10 seconds of real time, unless it sets `timeout`. Timers run on a virtual clock, so waiting doesn't use it up.
