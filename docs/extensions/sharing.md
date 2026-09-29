# Sharing

## An .orbext file

`orb package` builds the extension and zips `dist/` into `<name>.orbext`, and
`orb install` also asks OrbTorrent on this Mac to install it. Opening
it on a Mac with OrbTorrent, or choosing it with **Install Extension…** on the
Extensions page, shows the install sheet:

- what the extension does, and who made it;
- "Not reviewed by OrbTorrent";
- when it runs, and what it can do.

Installing a newer version shows the same sheet, with new permissions marked
**New**. Installed extensions live in
`~/Library/Application Support/OrbTorrent/Extensions/Installed`.

An extension can't use an official extension's name. A development copy loaded
with `orb dev` can, and stands in for the official one while it's loaded.

## Official extensions

Official extensions live in this repository's `extensions/` folder. Each is an
npm workspace package, built by `make extensions` and shipped inside
OrbTorrent.app.

To change one:

1. Change its code and tests, and add a line to its `CHANGELOG.md`.
2. Run `make test-extensions`.
3. Open a pull request.

CI runs every extension's tests and lint. When a pull request changes an
extension's hooks or permissions, CI posts the difference as a comment, so the
reviewer sees first what users will be asked to allow.
