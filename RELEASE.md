# Release roadmap

Everything between today and OrbTorrent's first public release, in order.
Planned on 29 September 2026. Features are done: this is the work of getting
OrbTorrent safely onto other people's Macs and keeping it up to date there.
"You" marks steps only the owner can do. For features after 1.0, see
[ROADMAP.md](ROADMAP.md).

## 1. Decisions

- [x] **Bundle ID:** `com.orbtorrent.mac`, and `com.orbtorrent.mac.dev`
  for OrbTorrent Dev. Chosen before anyone else installs the app, because
  after release a new bundle ID would wipe every user's settings, Keychain
  items and permissions.
- [ ] **Apple Developer Program,** applied for on 29 September 2026; waiting
  for Apple to verify, then the agreement and the US$99 payment. (You)
- [x] **Where the code lives:** the personal account, as
  `github.com/sanjevirau/OrbTorrent`, which the app, the extension docs
  (`docs/extensions/llms.txt`, `scripts/extension-docs.mjs`) and the Develop
  tab already link to. It can move to a GitHub organisation later. So
  nothing breaks then, anything built into the app, above all the update feed,
  goes on a domain we control, not a GitHub address.
- [x] **Copyright owner:** Sanjevi Rau, personally. "Copyright © 2026 Sanjevi
  Rau" is in the About window, the app's Info.plist and the README.
- [ ] **Check the name "OrbTorrent":** the domain, the GitHub name, the
  `@orbtorrent` npm scope (the SDK is `@orbtorrent/api`), and a trademark
  search. (You, with help)

## 2. Foundation

- [x] **Change the bundle ID everywhere.** Done on 29 September 2026. The
  owner's settings and the VirusTotal key moved from
  `io.github.sanjevirau.OrbTorrent` on the first launch
  (`IdentityMigration.swift`); the library didn't need to, since its folder is
  named after the app. By hand afterwards: OrbTorrent was made the default
  app for magnet links and .torrent files again, and "Open OrbTorrent when you
  log in" turned back on, and the old login item
  (`io.github.sanjevirau.OrbTorrent`) removed in System Settings.
- [x] **Split Dev from the daily app.**

  | | OrbTorrent (daily) | OrbTorrent Dev |
  |---|---|---|
  | Bundle ID | `com.orbtorrent.mac` | `com.orbtorrent.mac.dev` |
  | Built by | `make app` (Release) | `make dev` (Dev), and Debug for tests |
  | Where it lives | `/Applications` | `build/OrbTorrent Dev.app` |
  | Library, engine and settings | `Application Support/OrbTorrent` | `Application Support/OrbTorrent Dev`, starting empty |
  | Keychain items | `com.orbtorrent.mac.extension.<name>` | `com.orbtorrent.mac.dev.extension.<name>` |
  | Look | blue orb | amber orb, in the Dock and menu bar |
  | Opens magnet links and .torrent files | yes | no; drag in or File → Open |
  | Start at login | yes | no |
  | Updates | from releases | rebuilt during development |

  `AppIdentity.swift` decides the name, data folder and Keychain prefix from
  the bundle ID. During development only Dev is rebuilt and relaunched, and
  tests use free torrents, or a copy of the real library, never the live one.
  A change reaches the daily app only when the owner asks for it
  (`make install`, until updates exist), and through releases after that.
  `ORB_APP=dev orb dev` points the extension CLI at Dev.

  Two things not to do in Dev while the daily app has the same:
  - Import from Transmission or qBittorrent downloads the daily app already
    has, or two engines would work on the same files.
  - Turn on "Download only through a VPN" while the daily app has it on, or
    both would ask the VPN for its one forwarded port.
- [x] **Sign with a certificate.** `make` signs with the first certificate in
  the Keychain: for OrbTorrent a "Developer ID Application" one, else "Apple
  Development"; for Dev "Apple Development". For now that's
  `Apple Development: [removed] ([removed])`. Before this, builds
  were signed ad hoc, so macOS knew each one only by its file fingerprint,
  which changes with every build, and asked for permissions and Keychain
  access again after each rebuild. Now it knows the app by its bundle ID and
  certificate. It will ask once more when builds move to Developer ID
  certificates.
- [x] **First commit and push** to the private repo
  `github.com/sanjevirau/OrbTorrent`, on 29 September 2026. Whether it goes
  public is decided later.

## 3. What the release needs

- [ ] **Automatic updates** with Sparkle 2: "Check for Updates…" in the menu.
  Hosting is free on GitHub:
  - **The notarized disk images go on GitHub Releases,** as CI already
    publishes them. Sparkle downloads them from there.
  - **The update feed** (`appcast.xml`, a small file listing each version)
    goes on GitHub Pages, at an address on a domain we own, such as
    `updates.orbtorrent.com`. Every installed copy keeps asking that one
    address for as long as it's installed, so it must never change. A domain
    we own lets the repo move or be renamed without breaking it.
  - **While the repo is private, neither is reachable by other people.**
    Releases of a private repo can't be downloaded without access, and Pages
    for a private repo needs a paid GitHub plan. By the public beta, the repo
    must be public, or the releases and feed must live in a separate public
    repo.
  - **Updates are signed** with an EdDSA key the owner keeps safe, in the
    Keychain, a password manager and a GitHub secret. Losing it means
    existing users can't be updated.
  - Off in Dev. It has to be in the first release, since people with an
    existing copy can only get the updater through an update.
- [x] **About window,** from the app menu, the menu bar's ⋯ menu and
  Settings → About. It shows the orb, the version, the copyright and the GPL
  notice (free software, no warranty). Acknowledgements lists OrbTorrent,
  qBittorrent, libtorrent, Qt, OpenSSL and Boost, each with its version and
  licence text, from the Licenses folder the build embeds. Privacy has the
  note below, and Source Code links to the repo. A Sponsor link can come once
  GitHub Sponsors is set up.
- [ ] **Help menu:** the website and the extension docs, once both are public.
  Report a Problem waits in [ROADMAP.md](ROADMAP.md) until there's an email
  address and a domain for it.
- [x] **Privacy note,** in the About window and the README; the website
  still to come. OrbTorrent collects nothing and contacts only peers and
  trackers, the public tracker list (while "Find more peers for public
  torrents" is on), web addresses torrents are added from, and the sites each
  extension lists. The update feed joins the list once updates exist. The
  engine's lookup of peers' countries is now off
  (`Connection\ResolvePeerCountries`). OrbTorrent never showed countries, and
  the lookup downloaded a database from db-ip.com each month.
- [x] **Clean-up:**
  - Removed the Floe and bundle ID migrations and their tests.
  - The version is 1.0. Betas are 1.0 with rising build numbers
    (`CURRENT_PROJECT_VERSION`), called "1.0 beta N" in their release titles,
    so Sparkle sees each as newer.
  - Still to do before going public: fresh screenshots in the README.

## 4. Signing and notarization

- [ ] **Developer ID Application certificate and an App Store Connect API
  key** for notarization, once the developer account is approved. (You, with
  help)
- [ ] **CI signs and notarizes each release.** The certificate, its password,
  the API key and the update key go in GitHub secrets. CI signs the app, the
  engine (`qbittorrent-nox`) and the extension helper (`orb-extension-host`)
  with the hardened runtime, which is already on. `scripts/make-dmg.sh` then
  signs, notarizes and staples the disk image; it already takes
  `SIGN_IDENTITY` and `NOTARY_PROFILE`. Check the result with
  `spctl --assess` and `stapler validate`.
- [ ] **First notarized build.** Fix whatever Apple flags; the extra
  programs inside the app are the usual suspects.

Once signed with Developer ID, macOS knows the app by its bundle ID and Team
ID, which stay the same through every update and every certificate renewal.
Each user is asked once for each permission, and never again:
- the Downloads folder, and any other folder they save to;
- notifications;
- the local network, for opening the router's port and finding peers nearby;
- start at login, which shows up as a notice rather than a question.

The app's own Keychain items need no prompt at all. The macOS firewall, if
someone has it on, lets signed apps accept incoming connections
automatically.

## 5. Testing

- [ ] **Fresh user account:** download from GitHub like a stranger would.
  Then go through Gatekeeper (it must open without warnings), the welcome,
  importing from Transmission and qBittorrent, a magnet link and a .torrent
  file, the VPN, extensions, notifications, start at login, quitting and
  relaunching, and uninstalling.
- [ ] **Intel:** run the universal build's Intel half under Rosetta.
- [ ] **Updating:** install beta 1, publish beta 2, and confirm it updates
  without asking for any permission or Keychain access again.
- [ ] **Daily use:** the owner's daily app becomes the signed release build
  for a few days. (You)

## 6. Going public

- [ ] **Make the repo public** when ready (you decide):
  - Turn the build workflow back on for every push and pull request (see the
    comment in `.github/workflows/build.yml`). While private, it runs only for
    version tags and by hand, since macOS runners use private repos' free
    minutes ten times as fast.
  - Take the owner's account details out of this file first: the Apple
    Account, the enrollment ID and the certificate names.
  - Contribution rules. If paid "Pro" parts might ever come, require a
    contributor licence agreement, so the code can still be relicensed later.
  - Issue templates, and optionally GitHub Sponsors.
- [ ] **A simple website** on GitHub Pages: download, screenshots,
  requirements, privacy.
- [ ] **Public beta:** a GitHub release, posted on r/macapps. Then a week or
  two of fixes, shipped through the updater.
- [ ] **1.0.**
- [ ] **Homebrew cask.** Homebrew has a popularity bar for new casks and
  expects them to pass Gatekeeper, so this may come a little after launch.

## After 1.0

- Publish the extension SDK (`@orbtorrent/api`) to npm for outside developers.
- VPN partner links, clearly labelled, and only for VPNs that work with
  OrbTorrent's port forwarding (Proton VPN, Private Internet Access, AirVPN).
- A paid iPhone companion app: remote control, and a notification when a
  download finishes.
- The rest of [ROADMAP.md](ROADMAP.md).
