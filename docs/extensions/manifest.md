# Manifest

An extension's `package.json` is npm's, with OrbTorrent's fields added.

```json
{
  "name": "virustotal",
  "title": "VirusTotal Scan",
  "description": "Checks finished downloads against about 70 antivirus engines.",
  "author": "orbtorrent",
  "icon": "icon.png",
  "hooks": [{ "name": "scan", "title": "Scan with VirusTotal", "event": "afterFinish" }],
  "permissions": { "files": "contents", "network": ["www.virustotal.com"] },
  "preferences": [
    { "name": "apiKey", "type": "password", "title": "API key", "required": true }
  ],
  "verify": "verify",
  "dependencies": { "@orbtorrent/api": "^1.0.0" }
}
```

| Field | Required | Meaning |
|---|---|---|
| `name` | yes | A unique id: lowercase letters, digits and hyphens. |
| `title` | yes | Shown on the Extensions page and in the Checks tab. |
| `description` | yes | One sentence on what it does. |
| `author` | yes | Your name or handle. |
| `icon` | no | A 512×512 PNG in `assets/`. |
| `hooks` | yes | `{ "name", "title", "description"?, "event" }`. `event` is `beforeStart` or `afterFinish`. The hook named `check` is the default export of `src/check.ts`. |
| `permissions.files` | no | `"contents"` to fingerprint and upload the download's files. |
| `permissions.network` | no | Exact host names, such as `"www.virustotal.com"`. |
| `preferences` | no | Settings OrbTorrent draws on the Extensions page. |
| `verify` | no | Names `src/<verify>.ts`, which checks the settings when the user presses Verify. |

## Preferences

`{ "name", "type", "title", "description"?, "required"?, "placeholder"?, "default"?, "label"?, "data"? }`

| Type | Value | Notes |
|---|---|---|
| `textfield` | text | |
| `password` | text | Kept in the macOS Keychain and hidden in logs. It can't have a default. |
| `checkbox` | true or false | `label` sits next to the box. |
| `dropdown` | text | `data` lists `{ "title", "value" }`. |

While a `required` setting is empty, the extension shows **Setup** and its
hooks are skipped. Put setup steps in `help.md`, which OrbTorrent shows next to
the settings.

## What users see

The Extensions page lists what each extension **can** do, from `hooks` and
`permissions`:

- see the names and sizes of the files in your downloads (always);
- hold a download before it starts (with a `beforeStart` hook);
- read the contents of your downloads (`"files": "contents"`);
- connect to each host in `permissions.network`.

OrbTorrent enforces the list, so ask only for what the extension needs.
