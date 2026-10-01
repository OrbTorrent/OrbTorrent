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
- [x] **Domain: `orbtorrent.com`,** bought on 29 September 2026 through
  Cloudflare Registrar, on the owner's Cloudflare account. Its DNS is on
  Cloudflare, the registrar lock is on and the owner's details are hidden
  from public lookups. It expires on 29 September 2027. Auto-renew is off for
  now; it goes on before the public beta (see Going public). The update feed
  is at `updates.orbtorrent.com` (see Automatic updates), and the website
  goes at `orbtorrent.com`. `help@orbtorrent.com` forwards to the owner's
  Gmail through Cloudflare Email Routing, set up on 29 September 2026.
- [x] **Counting users:** no analytics in the app. The update feed counts
  update checks by version and build, which is roughly the Macs using each
  version each day (`updates/stats.sh`). With GitHub's download counts and,
  later, the website's Cloudflare Web Analytics, that's enough to see whether
  OrbTorrent is catching on. Opt-in usage counts only if a question comes up
  that these can't answer, asked in the app and listed in the privacy note.
- [x] **Hold the name "OrbTorrent":** the domain, the GitHub organisation
  `orbtorrent` (github.com/orbtorrent, owner's personal account as admin,
  holding the name; the code stays at `sanjevirau/OrbTorrent` for now), and
  the npm organisation `orbtorrent`, which reserves the `@orbtorrent` scope
  for the SDK (`@orbtorrent/api`). All on 29 September 2026.
- [ ] **Trademark search** for "OrbTorrent", before the public beta: MyIPO,
  and the USPTO and EUIPO databases. (You, with help)

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

- [x] **Automatic updates** with Sparkle 2.10, done on 29 September 2026.
  It has to be in the first release, since people can only get the updater
  through an update.
  - **In the app:** a check once a day, "Check for Updates…" in the app menu
    and the menu bar's ⋯ menu, and Settings → General → Updates. An update
    found while OrbTorrent is in the background waits quietly in the menu
    bar panel, a banner in the window and a notification, instead of popping
    up. Off in Dev, except from a test feed.
  - **What's New:** after an update, the window shows the new version's
    release notes, as written on GitHub, in the welcome's style; after
    skipping updates, every release's since. Help → What's New shows it again.
  - **The feed** is at `https://updates.orbtorrent.com/appcast.xml`, which
    must never change. It's served by the Cloudflare Worker
    `orbtorrent-updates` (`updates/`), from the KV namespace
    `orbtorrent-updates`, and counts each check by version and build in the
    Analytics Engine dataset `orbtorrent_update_checks`, without the address
    it came from. Free up to 100,000 checks a day.
  - **The disk images** are downloaded from GitHub Releases. While the repo
    is private, they can't be downloaded by other people, so by the public
    beta the repo must be public, or the releases must live in a separate
    public repo.
  - **Signing:** the feed and each update are signed with an EdDSA key in the
    owner's login Keychain (account `orbtorrent`), whose public half is in
    the app. Losing it means existing users can't be updated.
  - **Publishing** (see the README): tag, write the notes on the GitHub
    release and publish it, then run `scripts/publish-update.sh <tag>`.
  - **Tested** on 29 September 2026: OrbTorrent Dev build 1 updated itself to
    build 3 from a test feed listing builds 2 and 3, checked both signatures,
    installed on quit and opened What's New.
    Publishing was tried from a throwaway GitHub release, without uploading.
- [x] **Back up the update key:** in the owner's password manager, since 29
  September 2026. On a new Mac, `build/sparkle/bin/generate_keys --account
  orbtorrent -f <file>` puts it back in the Keychain.
- [x] **About window,** from the app menu, the menu bar's ⋯ menu and
  Settings → About. It shows the orb, the version, the copyright and the GPL
  notice (free software, no warranty). Acknowledgements lists OrbTorrent,
  qBittorrent, libtorrent, Qt, OpenSSL and Boost, each with its version and
  licence text, from the Licenses folder the build embeds. Privacy has the
  note below, and Source Code links to the repo. A Sponsor link can come once
  GitHub Sponsors is set up.
- [x] **Help menu:** What's New, and Report a Problem, which is also in the
  menu bar's ⋯ menu. The report shows OrbTorrent's, macOS's and the engine's
  versions and the Mac, and optionally the engine's last 60 log lines with IP
  addresses and the user name hidden, then opens the person's mail app
  addressed to `help@orbtorrent.com`. Nothing is sent on its own.
- [x] **Extension SDK on npm,** so anyone can build extensions with
  `npm create @orbtorrent/extension@latest <name>`: `@orbtorrent/api` (the API and
  the `orb` tool) and `@orbtorrent/create-extension`, 1.0.0, published by the
  owner on 29 September 2026. Both are MIT licensed, so extensions can use any
  licence (the app stays GPL). The Develop tab, guides and Agent Skill say
  `npm create`. Tested first from a stand-in registry outside the repo (both
  templates made, installed, tested, built, linted and packaged, and one run
  on a download in OrbTorrent Dev), then again from npm itself once live.
- [x] **Trusted publishing for the SDK,** set up by the owner on 29
  September 2026: both packages trust GitHub Actions in
  `sanjevirau/OrbTorrent`, workflow `sdk.yml`, and their publishing access
  requires two-factor authentication and disallows tokens. So `sdk-v*` tags
  publish from CI (`.github/workflows/sdk.yml`), and otherwise only the owner
  can publish, by hand with two-factor authentication. If the repo moves to
  the `orbtorrent` organisation, change the trusted publisher on npmjs.com and
  the packages' `repository` to match.
- [x] **Building extensions with AI,** on 29 September 2026. The Develop tab
  has the development switch as a slim row on top, then **Build an
  Extension** with a With AI / Yourself toggle, then what's in development,
  with the guides and agent files in one Resources panel. With AI: the user
  says what the extension should do,
  and it becomes a request to paste into Claude Code, Codex, Cursor, Gemini CLI
  or another coding agent, with the three steps only the user takes (allowing
  development extensions, allowing the folder, confirming the install). `orb`
  gained `doctor` (what's missing, and who must fix it), `downloads`, and
  `install`, which shows the install sheet and waits for the user's answer.
  Installing replaces a development copy. `scripts/agent-eval.mjs` tests it:
  Claude Code and Codex each built all three test extensions right, Cursor
  wasn't signed in. That testing found `npm create` reusing an old cached
  template, fixed in 1.0.2 and by saying `npm create
  @orbtorrent/extension@latest` everywhere (1.0.3). `@orbtorrent/api` 1.0.1 to
  1.0.3 were published by GitHub Actions through trusted publishing the same
  day, the first releases from CI. Later, once the repo is public: the Agent
  Skill through `npx skills add`, and the docs on Context7.
- [ ] **Help menu, later:** the website and the extension docs, once both are
  public, and a GitHub issue as another way to report, once the repo is.
- [x] **Privacy note,** in the About window and the README; the website
  still to come. OrbTorrent collects nothing and contacts only peers and
  trackers, the public tracker list (while "Find more peers for public
  torrents" is on), web addresses torrents are added from, and the sites each
  extension lists, and `updates.orbtorrent.com` once a day and github.com
  for an update. The engine's lookup of peers' countries is now off
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
  programs inside the app are the usual suspects. Sparkle's helpers are
  already re-signed with the app's certificate and the hardened runtime.
- [ ] **CI publishes updates too,** once it notarizes: the update key and a
  Cloudflare API token that can only write the feed's KV namespace go in
  GitHub secrets, and a job runs `scripts/publish-update.sh` when a release
  is published. Until then, publish from the owner's Mac.

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

- [ ] **Turn on auto-renew for `orbtorrent.com`** before the public beta.
  Whoever holds the domain controls where every installed copy looks for
  updates, so it must never lapse. (You)
- [ ] **Make the repo public** when ready (you decide):
  - Turn the build workflow back on for every push and pull request (see the
    comment in `.github/workflows/build.yml`). While private, it runs only for
    version tags and by hand, since macOS runners use private repos' free
    minutes ten times as fast.
  - Take the owner's account details out of this file first: the Apple
    Account, the enrollment ID and the certificate names. They're also in
    the first commit (`ebaff17`), and making the repo public publishes its
    whole history, so rewrite the history without them too, before it goes
    public.
  - The licence is GPL-3.0-or-later. The README says the OrbTorrent name and
    the orb icon aren't covered by it (GPL section 7(e)), so forks must use
    their own. Registering "OrbTorrent" as a trademark with MyIPO would back
    that up; the domain alone doesn't protect the name. (You, optional)
  - Contribution rules. If paid "Pro" parts might ever come, require a
    contributor licence agreement, so the code can still be relicensed later.
  - Issue templates, and optionally GitHub Sponsors.
- [ ] **A simple website** at `orbtorrent.com`: download, screenshots,
  requirements, privacy. Cloudflare Pages, since the domain is there, with
  Cloudflare Web Analytics.
- [ ] **Public beta:** a GitHub release, posted on r/macapps, quietly. Then
  fixes, shipped through the updater. See [LAUNCH.md](LAUNCH.md).
- [ ] **1.0,** the big launch, at least 30 days after the beta's r/macapps
  post, since r/macapps allows one a month. Everything about it is in
  [LAUNCH.md](LAUNCH.md).
- [ ] **Homebrew cask.** Homebrew has a popularity bar for new casks and
  expects them to pass Gatekeeper, so this may come a little after launch.

## After 1.0

- VPN partner links, clearly labelled, and only for VPNs that work with
  OrbTorrent's port forwarding (Proton VPN, Private Internet Access, AirVPN).
- A paid iPhone companion app: remote control, and a notification when a
  download finishes.
- The rest of [ROADMAP.md](ROADMAP.md).
