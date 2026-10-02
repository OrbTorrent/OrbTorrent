---
title: Share and install
description: Install your extension, package it as an .orbext file anyone can install, release updates, and list it or propose it as an official extension.
---

## Install it yourself

When your extension does what you want:

```sh
npx orb install
```

`orb install` builds and packages the extension, then asks OrbTorrent to install it. OrbTorrent shows the install sheet: what the extension does, who made it, when it runs, and what it can do. It installs it when you confirm, and the installed copy replaces the one loaded for development. `orb install` waits for your answer, then says whether it was installed.

## Make an .orbext file

To install it on another Mac, or give it to someone:

```sh
npx orb package
```

```txt title="Output"
✓ Made no-screensavers.orbext. Open it on a Mac with OrbTorrent to install it.
```

An `.orbext` file is the built extension, zipped. To install one, open it on a Mac with OrbTorrent, or choose **Install Extension…** from OrbTorrent's **File** menu or the Extensions page. OrbTorrent shows the same install sheet:

- what the extension does, and who made it;
- **Not reviewed by OrbTorrent**;
- when it runs, and what it can do.

Installed extensions live in `~/Library/Application Support/OrbTorrent/Extensions/Installed`.

## Release an update

1. Raise `"version"` in `package.json`, such as from `1.0.0` to `1.1.0`, and add a line to `CHANGELOG.md`.
2. Run `npx orb package` again, and share the new file.

Opening it shows the install sheet again, with anything new the extension can do marked **New**, such as another host it connects to. Settings and storage are kept across updates.

## Before you share

- **Ask for the least you need.** People see every permission, and decide on them.
- **Write a clear `description`,** one sentence on what it does, and a `title` people will recognise in the Checks tab.
- **Add an icon:** a 512 × 512 PNG in `assets/`, named in `"icon"`.
- **Put setup steps in `help.md`,** if it needs an API key or an account.
- **Test what must pass,** not only what it catches.
- **Choose a licence.** `@orbtorrent/api` is MIT, so your extension can use any licence.

## Names

An extension's `name` is its id: lowercase letters, digits and hyphens, unique among the extensions someone has installed. An installed extension can't use an official extension's name. A development copy loaded with `orb dev` can, and stands in for the official one while it's loaded.

## The community list

Made an extension others would like? Add it to the **Community** list in OrbTorrent's [README](https://github.com/sanjevirau/OrbTorrent#community) with a pull request that adds one line, in alphabetical order. For it to be listed:

- its source is public, with a licence;
- a release there has the `.orbext` file, built from that source with `npx orb package`;
- its tests pass, with `npx orb test`;
- the line says what it does, and what it's allowed to do: each host it connects to, and whether it reads or adds files.

Listings are checked against these rules, not reviewed line by line, and the list says so. If a listed extension stops working, or does something its line doesn't say, it comes off the list.

## Propose an official extension

Official extensions ship inside OrbTorrent, are under its licence (GPL-3.0-or-later), and are kept working by its maintainers. Before you build one, open an issue with the [Propose an official extension](https://github.com/sanjevirau/OrbTorrent/issues/new?template=official_extension.yml) form. An official extension:

- is useful to most people who use OrbTorrent;
- works without an account, or makes one optional;
- has nothing to do with finding or getting copyrighted material;
- asks for the least it needs.

Once it's agreed, add it in the repository's `extensions/` folder, laid out like the others, with a `README.md`, a `CHANGELOG.md` and tests for every rule, and open a pull request. [CONTRIBUTING.md](https://github.com/sanjevirau/OrbTorrent/blob/main/CONTRIBUTING.md) has the steps.

## Change an official extension

The official extensions, the Fake Download Check and VirusTotal Scan, live in the OrbTorrent repository's [`extensions/`](https://github.com/sanjevirau/OrbTorrent/tree/main/extensions) folder. Each is an npm workspace package, built by `make extensions` and shipped inside OrbTorrent.

To change one:

1. Change its code and tests, and add a line to its `CHANGELOG.md`.
2. Run `make test-extensions`.
3. Open a pull request.

CI runs every extension's tests and lint. When a pull request changes an extension's hooks or permissions, CI posts the difference as a comment, so the reviewer sees first what users will be asked to allow. Say in the pull request why it needs them.
