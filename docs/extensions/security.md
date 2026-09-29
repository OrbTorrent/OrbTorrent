# Security

Extensions are code from someone else running on the user's Mac. OrbTorrent
limits what that code can do, and doesn't rely on reviewing it alone.

## The extension host

- **A fresh process for every run.** Each hook runs in its own
  `orb-extension-host` process, which exits when the hook returns. Nothing
  carries over except through `storage`.
- **A strict macOS sandbox.** The helper has the App Sandbox entitlement and
  nothing else. It can't read or write files, connect to the network, or even
  look up a host name, and programs it starts inherit the same sandbox.
- **Everything goes through OrbTorrent.** Every request, file fingerprint,
  upload and storage write goes to OrbTorrent as a message, and OrbTorrent
  checks it against the extension's permissions first.
- **Limits.** OrbTorrent enforces time, CPU and memory limits, and kills a
  helper that goes over them. A `beforeStart` check that doesn't finish lets the
  download start.
- **JIT, only in the helper.** JavaScriptCore's JIT is on in the sandboxed
  helper, not in OrbTorrent itself.

## Network

- HTTPS only, on port 443, to hosts listed exactly in `permissions.network`.
- Redirects are followed only to hosts on the same list.
- A host that resolves to an address on the Mac or a local network is refused.
- There are no cookies and no shared cache.

## Settings and secrets

- **Passwords go in the Keychain.** `password` settings are stored in the macOS
  Keychain, not in a file.
- **An extension sees only its own settings.**
- **Secrets are hidden in logs.** OrbTorrent replaces them in its logs.
- **Removing an extension deletes its settings and storage.**

## Development

`orb dev` and `orb run` reach OrbTorrent through a socket at
`~/Library/Application Support/OrbTorrent/dev.sock`:

- only the user's account can open it (mode 0600, and the connecting process's
  user is checked);
- it's only there while **Allow development extensions** is on;
- OrbTorrent asks the first time each folder is loaded.
