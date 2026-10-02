# Contributing to OrbTorrent

Thanks for helping. Bug reports, fixes and extensions are all welcome.

## Reporting a problem

- **In the app:** Help → Report a Problem fills in OrbTorrent's, macOS's and
  the engine's versions, and can add the engine's recent log with addresses
  hidden. It goes from your own mail app to `help@orbtorrent.com`.
- **On GitHub:** open an issue with the bug report form. Copy the versions from
  Report a Problem or the About window.
- **Security problems** go privately to `help@orbtorrent.com`, not in an issue.
  See [SECURITY.md](SECURITY.md).

## Suggesting a feature

Check [ROADMAP.md](ROADMAP.md) first: it lists what's planned, what's been
decided against, and why. Then open an issue with the feature request form.
OrbTorrent aims to stay small and to fit in on a Mac, so not every good idea
will make it in. Many fit better as an extension (see below).

## Changing the code

For anything bigger than a small fix, open an issue first so we can agree on
the approach before you spend time on it.

1. Build it as [docs/development.md](docs/development.md#building)
   says. Work in **OrbTorrent Dev** (`make dev`), which has its own library
   and settings, so it can run beside your everyday OrbTorrent.
2. Match the code around your change: its naming, structure and amount of
   comments. Text people see in the app is short, plain English.
3. Add or update tests for what you change, and run them:

   ```sh
   make test              # the app's tests
   make test-extensions   # the extension SDK and the official extensions
   ```

4. For a change you can see, put before and after screenshots in the pull
   request.
5. Write commit messages that say what changes for people using OrbTorrent,
   such as "Show each peer's country flag in the Peers tab".

## Using a coding agent

Coding agents are welcome. [AGENTS.md](AGENTS.md) tells yours how OrbTorrent
is built, tested and written, and what must stay true; Claude Code reads it
through `CLAUDE.md`. You're still the author:

- read every line before you send it, and try it in OrbTorrent Dev;
- say in the pull request which agent helped;
- keep it to one change, and to the issue it's for.

A pull request that nobody has read or tried may be closed without a review.

## Extensions

### Your own extension

Extensions don't need to be in this repo. Make one with
`npm create @orbtorrent/extension@latest <name>`, see
[the extension docs](https://orbtorrent.com/docs/extensions), and share it as
an `.orbext` file.

To add it to the README's [community list](README.md#community), open a pull
request that adds one line to it, in alphabetical order. For it to be listed:

- its source is public, with a licence;
- a release there has the `.orbext` file, built from that source with
  `npx orb package`;
- its tests pass, with `npx orb test`;
- the line says what it does, and what it's allowed to do: each host it
  connects to, and whether it reads or adds files.

We check a listing against these rules, not its code line by line, and the
list says so. Anyone who installs it sees what it's allowed to do first, and
OrbTorrent runs it in a sandbox. If a listed extension stops working, or does
something its line doesn't say, it comes off the list.

### A new official extension

Official extensions ship inside OrbTorrent, are under its licence, and are
kept working by its maintainers. So before you build one, open an issue with
the **Propose an official extension** form. An official extension:

- is useful to most people who use OrbTorrent;
- works without an account, or makes one optional;
- has nothing to do with finding or getting copyrighted material;
- asks for the least it needs.

Once it's agreed, add it in `extensions/<name>/`, laid out like the others,
with `"license": "GPL-3.0-or-later"`, a `README.md`, a `CHANGELOG.md` and
tests for every rule. Then follow [Changing the code](#changing-the-code).
CI comments on the pull request with everything users will be asked to allow.

### Changing an official extension

Changes to the official extensions in `extensions/` follow the same steps as
the app. Every rule has tests in the extension's `tests/` folder, and a change
to what it's allowed to do needs a reason in the pull request.

## Licence

OrbTorrent is under the [GPL-3.0-or-later](LICENSE), and the extension SDK in
`sdk/` is under the [MIT licence](sdk/LICENSE). By sending a pull request, you
agree that your contribution is under the same licence as the code it changes.
There's no contributor licence agreement to sign.

The name OrbTorrent and the orb icon aren't covered by the GPL (see
[Name and icon](README.md#name-and-icon)), so please don't change them in a
pull request.
