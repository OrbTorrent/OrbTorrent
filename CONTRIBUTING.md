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

## Building an extension

Extensions don't need to be in this repo. Make one with
`npm create @orbtorrent/extension@latest <name>`, and see
[the extension docs](https://orbtorrent.com/docs/extensions). Changes to the official
extensions in `extensions/` follow the same steps as the app, and every rule
there has tests in its `tests/` folder.

## Licence

OrbTorrent is under the [GPL-3.0-or-later](LICENSE), and the extension SDK in
`sdk/` is under the [MIT licence](sdk/LICENSE). By sending a pull request, you
agree that your contribution is under the same licence as the code it changes.
There's no contributor licence agreement to sign.

The name OrbTorrent and the orb icon aren't covered by the GPL (see
[Name and icon](README.md#name-and-icon)), so please don't change them in a
pull request.
