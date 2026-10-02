---
title: Manifest
description: Every field of an extension's package.json, OrbTorrent's rules for each, and what users see from it.
---

An extension's `package.json` is npm's, with OrbTorrent's fields added. `orb build` checks it against the same rules OrbTorrent does, with the same messages.

```json title="package.json"
{
  "name": "virustotal",
  "title": "VirusTotal Scan",
  "description": "Checks finished downloads against about 70 antivirus engines, by each file's fingerprint.",
  "author": "orbtorrent",
  "icon": "icon.png",
  "license": "GPL-3.0-or-later",
  "version": "1.0.0",
  "hooks": [
    {
      "name": "scan",
      "title": "Scan with VirusTotal",
      "description": "Looks up each file's fingerprint on VirusTotal, riskiest files first.",
      "event": "afterFinish"
    }
  ],
  "permissions": { "files": "contents", "network": ["www.virustotal.com"] },
  "preferences": [
    { "name": "apiKey", "type": "password", "title": "API key", "description": "Your free VirusTotal API key.", "required": true }
  ],
  "verify": "verify",
  "dependencies": { "@orbtorrent/api": "^1.0.0" }
}
```

## Fields

| Field | Required | Meaning |
|---|---|---|
| `name` | Yes | A unique id: lowercase letters, digits and hyphens, such as `fake-download-check`, up to 64 characters. |
| `title` | Yes | Shown on the Extensions page and in the Checks tab. |
| `description` | Yes | One sentence on what it does. |
| `author` | Yes | Your name or handle. |
| `icon` | No | A 512 × 512 PNG in `assets/`. Without one, OrbTorrent shows a plain icon. |
| `version` | No | Such as `1.0.0`, shown on its page. Raise it with each change you install or share. |
| `license` | No | npm's, such as `MIT`. Shown on its page. |
| `hooks` | Yes | At least one [hook](#hooks). |
| `permissions` | No | What it can reach beyond file names and sizes. See [permissions](#permissions). |
| `preferences` | No | Its [settings](#preferences). |
| `verify` | No | Names `src/<verify>.ts`, which checks the settings when the user presses **Verify**. Lowercase letters, digits and hyphens. |

Everything else, such as `scripts`, `dependencies` and `private`, is npm's, and OrbTorrent ignores it.

## Hooks

```json
{ "name": "check", "title": "Check for signs of a fake", "description": "Looks at the names and sizes of a download's files.", "event": "beforeStart" }
```

| Field | Required | Meaning |
|---|---|---|
| `name` | Yes | Lowercase letters, digits and hyphens. The hook is the default export of `src/<name>.ts`, or `.tsx`, `.js` or `.jsx`. Two hooks can't share a name. |
| `event` | Yes | `beforeStart` or `afterFinish`. [Hooks](/docs/extensions/hooks) explains each. |
| `title` | No | Shown in the Checks tab and on the extension's page. The name, if you leave it out. |
| `description` | No | A line on what it does, shown on the extension's page. |

## Permissions

```json
{ "permissions": { "files": "contents", "network": ["www.virustotal.com", "api.example.com"] } }
```

| Field | Meaning |
|---|---|
| `files` | `"contents"` lets the extension fingerprint and upload the download's files, in `afterFinish` hooks. Without it, it sees only names and sizes. |
| `network` | Exact host names it can reach over HTTPS, without `https://` or a path, such as `"www.virustotal.com"`. No wildcards. |

[Network requests](/docs/extensions/network) and [Reading files](/docs/extensions/files) explain what each allows.

## Preferences

```json
{
  "name": "scope",
  "type": "dropdown",
  "title": "Files to check",
  "description": "Films and music rarely carry malware, and each lookup counts towards your daily limit.",
  "required": false,
  "default": "risky",
  "data": [
    { "title": "Programs, archives and documents", "value": "risky" },
    { "title": "All files", "value": "all" }
  ]
}
```

| Field | Required | Meaning |
|---|---|---|
| `name` | Yes | Letters, digits and underscores, starting with a letter, such as `apiKey`. The key in `getPreferenceValues()`. |
| `type` | Yes | `textfield`, `password`, `checkbox` or `dropdown`. |
| `title` | No | The setting's label. The name, if you leave it out. |
| `description` | No | A line under it. |
| `required` | No | `true` if the extension can't run without it. While it's empty, the extension shows **Needs setup**, and its hooks are skipped. |
| `placeholder` | No | Shown in an empty `textfield` or `password`. |
| `default` | No | Its value until the user changes it. Text for a `textfield`, `true` or `false` for a `checkbox`, one of `data`'s values for a `dropdown`. A `password` can't have one. |
| `label` | No | For a `checkbox`: the text beside the box. |
| `data` | For a dropdown | The choices, as `{ "title", "value" }`. |

[Settings](/docs/extensions/settings) explains how they're drawn and read.

## What users see

The Extensions page and the install sheet list what each extension **can** do, from its `hooks` and `permissions`:

- "See the names and sizes of the files in your downloads", always;
- "Hold a download before it starts, until you decide", with a `beforeStart` hook;
- "Read the contents of your downloads", with `"files": "contents"`;
- "Connect to …", for each host in `permissions.network`.

OrbTorrent enforces the list, so ask only for what the extension needs.

## Other files

| File | |
|---|---|
| `src/<hook>.ts` | Each hook, and `src/<verify>.ts`. |
| `assets/` | The icon, and anything else it shows. |
| `help.md` | Setup steps, shown beside the settings under **How to Set It Up**. |
| `README.md`, `CHANGELOG.md` | Copied into the built extension. |
| `tests/*.json` | [Tests](/docs/extensions/reference/tests), which aren't shipped. |
| `orb-env.d.ts` | Written by `orb build`, with the settings' types. Don't edit it. |
| `AGENTS.md`, `CLAUDE.md` | Instructions for coding agents, which aren't shipped. |

## What OrbTorrent loads

`orb build` writes the manifest OrbTorrent reads to `dist/package.json`: just OrbTorrent's fields, with defaults filled in, and the version of `@orbtorrent/api` it was built with:

```json title="dist/package.json"
{
  "name": "notify-me",
  "title": "Notify Me",
  …
  "orbtorrent": { "api": "1.0.3" }
}
```

OrbTorrent uses that version to check it supports the extension's API. [Versions](/docs/extensions/reference/api#versions) explains.
