# Release roadmap

Everything between today and OrbTorrent's first public release, in order.
Planned on 29 September 2026. Features are done: this is the work of getting
OrbTorrent safely onto other people's Macs and keeping it up to date there.
"You" marks steps only the owner can do. What's done and what's left is
tracked in [CHECKLIST.md](CHECKLIST.md); this file has the details. For
features after 1.0, see [ROADMAP.md](ROADMAP.md).

## 1. Decisions

- **Bundle ID:** `com.orbtorrent.mac`, and `com.orbtorrent.mac.dev`
  for OrbTorrent Dev. Chosen before anyone else installs the app, because
  after release a new bundle ID would wipe every user's settings, Keychain
  items and permissions.
- **Apple Developer Program,** applied for on 29 September 2026; waiting
  for Apple to verify, then the agreement and the US$99 payment. (You)
- **Where the code lives:** the personal account, as
  `github.com/sanjevirau/OrbTorrent`. It can move to a GitHub organisation
  later. So nothing breaks then, anything built into the app, above all the
  update feed, goes on a domain we control, not a GitHub address: the Develop
  tab's guides and llms.txt link to orbtorrent.com/docs.
- **Copyright owner:** Sanjevi Rau, personally. "Copyright © 2026 Sanjevi
  Rau" is in the About window, the app's Info.plist and the README.
- **Domain: `orbtorrent.com`,** bought on 29 September 2026 through
  Cloudflare Registrar, on the owner's Cloudflare account. Its DNS is on
  Cloudflare, the registrar lock is on and the owner's details are hidden
  from public lookups. It expires on 29 September 2027, and auto-renew is off,
  so it's renewed by hand before then. The update feed
  is at `updates.orbtorrent.com` (see Automatic updates), and the website
  goes at `orbtorrent.com`. `help@orbtorrent.com` forwards to the owner's
  Gmail through Cloudflare Email Routing, set up on 29 September 2026 and
  tested on 1 October 2026 with an email from another inbox.
- **Counting users:** anonymous counts with the daily update check, no
  ID (`AnonymousCounts.swift`): the version, macOS, chip, install week, first
  check ever, this week and this month, and unexpected quits of the app and
  the engine. On unless turned off in Settings, which shows exactly what's
  sent. `updates/stats.sh` turns them into Macs a day, week and month,
  installs, versions, quits per version, how many keep using it, and macOS
  and chip. Chosen on 2 October 2026 over "no analytics", so a bad release
  shows up within a day, now that updates install themselves. Nothing about
  how it's used: an opt-in for that (features, downloads, opened or not) was
  built and taken out again for launch, as these answer what matters. Add it
  only if a question comes up that they can't.
- **Say what's counted at launch,** in the first release's notes and the
  announcement, pointing to orbtorrent.com/privacy#counts, rather than let
  someone find it.
- **Hold the name "OrbTorrent":** the domain, the GitHub organisation
  `orbtorrent` (github.com/orbtorrent, owner's personal account as admin,
  holding the name; the code stays at `sanjevirau/OrbTorrent` for now), and
  the npm organisation `orbtorrent`, which reserves the `@orbtorrent` scope
  for the SDK (`@orbtorrent/api`). All on 29 September 2026.

## 2. Foundation

- **Change the bundle ID everywhere.** Done on 29 September 2026. The
  owner's settings and the VirusTotal key moved from
  `io.github.sanjevirau.OrbTorrent` on the first launch
  (`IdentityMigration.swift`); the library didn't need to, since its folder is
  named after the app. By hand afterwards: OrbTorrent was made the default
  app for magnet links and .torrent files again, and "Open OrbTorrent when you
  log in" turned back on, and the old login item
  (`io.github.sanjevirau.OrbTorrent`) removed in System Settings.
- **Split Dev from the daily app.**

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
- **Sign with a certificate.** `make` signs with the first certificate in
  the Keychain: for OrbTorrent a "Developer ID Application" one, else "Apple
  Development"; for Dev "Apple Development". For now that's the owner's
  personal Apple Development certificate. Before this, builds
  were signed ad hoc, so macOS knew each one only by its file fingerprint,
  which changes with every build, and asked for permissions and Keychain
  access again after each rebuild. Now it knows the app by its bundle ID and
  certificate. It will ask once more when builds move to Developer ID
  certificates.
- **First commit and push** to the private repo
  `github.com/sanjevirau/OrbTorrent`, on 29 September 2026. Whether it goes
  public is decided later.

## 3. What the release needs

- **Automatic updates** with Sparkle 2.10, done on 29 September 2026.
  It has to be in the first release, since people can only get the updater
  through an update.
  - **In the app:** a check once a day, "Check for Updates…" in the app menu
    and the menu bar's ⋯ menu, and Settings → General → Updates. Updates
    download in the background and install themselves (on by default since
    2 October 2026): OrbTorrent restarts once it isn't in use, meaning not in
    front, or no input for two minutes, and nothing would be cut short (an
    import, files moving or being checked, an extension's check). It comes
    back in the menu bar; "Restart to Update" in the panel and the window
    does it at once. With that off, Sparkle's window offers each update, and
    one found in the background waits in the panel, a banner and a
    notification, unless it's critical. Off in Dev, except from a test feed.
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
  - **Publishing** (see docs/development.md): tag, write the notes on the GitHub
    release and publish it, then run `scripts/publish-update.sh <tag>`.
    `--critical` for a fix nobody can skip, `--phased` to reach Macs over a
    week, and `--withdraw <tag>` to take a bad version off the feed.
  - **Tested** on 29 September 2026: OrbTorrent Dev build 1 updated itself to
    build 3 from a test feed listing builds 2 and 3, checked both signatures,
    installed on quit and opened What's New.
    Publishing was tried from a throwaway GitHub release, without uploading.
    On 1 October 2026, through Sparkle's own window too: Check for Updates…
    showed 1.0 beta 4's notes, Install Update downloaded and checked it, and
    Install and Relaunch reopened build 4 with What's New.
    On 2 October 2026, installing by itself: Dev build 1's daily check sent
    the anonymous counts, downloaded build 5 and showed "1.0 beta 5 is
    ready"; with no one at the Mac it restarted 66 s later into build 5, in
    the menu bar only, and What's New showed when the window opened.
- **Back up the update key:** in the owner's password manager, since 29
  September 2026. On a new Mac, `build/sparkle/bin/generate_keys --account
  orbtorrent -f <file>` puts it back in the Keychain.
- **About window,** from the app menu, the menu bar's ⋯ menu and
  Settings → About. It shows the orb, the version, the copyright and the GPL
  notice (free software, no warranty). Acknowledgements lists OrbTorrent,
  qBittorrent, libtorrent, Qt, OpenSSL and Boost, each with its version and
  licence text, from the Licenses folder the build embeds. Privacy has the
  note below, and Source Code links to the repo. A Sponsor link can come once
  GitHub Sponsors is set up.
- **Help menu:** What's New, and Report a Problem, which is also in the
  menu bar's ⋯ menu. The report shows OrbTorrent's, macOS's and the engine's
  versions and the Mac, and optionally the engine's last 60 log lines with IP
  addresses and the user name hidden, then opens the person's mail app
  addressed to `help@orbtorrent.com`. Nothing is sent on its own.
- **Extension SDK on npm,** so anyone can build extensions with
  `npm create @orbtorrent/extension@latest <name>`: `@orbtorrent/api` (the API and
  the `orb` tool) and `@orbtorrent/create-extension`, 1.0.0, published by the
  owner on 29 September 2026. Both are MIT licensed, so extensions can use any
  licence (the app stays GPL). The Develop tab, guides and Agent Skill say
  `npm create`. Tested first from a stand-in registry outside the repo (both
  templates made, installed, tested, built, linted and packaged, and one run
  on a download in OrbTorrent Dev), then again from npm itself once live.
- **Trusted publishing for the SDK,** set up by the owner on 29
  September 2026: both packages trust GitHub Actions in
  `sanjevirau/OrbTorrent`, workflow `sdk.yml`, and their publishing access
  requires two-factor authentication and disallows tokens. So `sdk-v*` tags
  publish from CI (`.github/workflows/sdk.yml`), and otherwise only the owner
  can publish, by hand with two-factor authentication. npm ties this to the
  repo itself, not just its name: when the repo was deleted and created again
  on 1 October 2026, both packages' trusted publishers had to be removed and
  added again, then a test run got a publishing token for each without
  publishing. Do the same if the repo moves to the `orbtorrent`
  organisation, and change the packages' `repository` to match.
- **Building extensions with AI,** on 29 September 2026. The Develop tab
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
  Claude Code and Codex each built all three test extensions right, and
  Cursor did too on 1 October 2026. That testing found `npm create` reusing
  an old cached template, fixed in 1.0.2 and by saying `npm create
  @orbtorrent/extension@latest` everywhere (1.0.3). `@orbtorrent/api` 1.0.1 to
  1.0.3 were published by GitHub Actions through trusted publishing the same
  day, the first releases from CI. Later, once the repo is public: the Agent
  Skill through `npx skills add`, and the docs on Context7.
- **Fake Download Check, sharpened,** on 1 October 2026. Of 25 tricky
  downloads it got 2 right: it held Mac apps with "4K", "HDR" or "Blu-ray" in
  their names, RARBG releases, scene releases of *Passengers* and *Key Largo*,
  and coding courses, and missed fakes named without a quality, programs in
  albums and books, Mac scripts and screensavers, and zero-width padding. It
  now works out what a download is from its files and then its name, and gets
  all 25 right, with 61 tests that the app's tests also run in its own
  extension host. Still beyond names and sizes: a fake with believable ones,
  which needs reading files after they arrive (a new extension API) or release
  dates from a film database (see ROADMAP.md).
- **Help menu:** OrbTorrent Help (the docs, ⌘?), Troubleshooting and the
  website, all on orbtorrent.com. The Develop tab links the extension docs.
- **A GitHub issue as another way to report,** from Report a Problem, once
  the repo is public.
- **Privacy note,** in the About window, the README and the website.
  OrbTorrent knows nothing about you, counts only anonymously (see Counting
  users), and contacts only peers and
  trackers, the public tracker list (while "Find more peers for public
  torrents" is on), web addresses torrents are added from, and the sites each
  extension lists, and `updates.orbtorrent.com` once a day and github.com
  for an update, and download.db-ip.com once a month for the country
  database behind peers' flags in the Peers tab
  (`Connection\ResolvePeerCountries`), credited in Acknowledgements.
- **Clean-up:**
  - Removed the Floe and bundle ID migrations and their tests.
  - The version is 1.0. Betas are 1.0 with rising build numbers
    (`CURRENT_PROJECT_VERSION`), called "1.0 beta N" in their release titles,
    so Sparkle sees each as newer.
  - The README's three old screenshots are now one image of the app as it
    is (1 October 2026).

## 4. Signing and notarization

- **Developer ID Application certificate and an App Store Connect API
  key** for notarization, once the developer account is approved. (You, with
  help)
- **CI signs and notarizes each release.** The certificate, its password,
  the API key and the update key go in GitHub secrets. CI signs the app, the
  engine (`qbittorrent-nox`) and the extension helper (`orb-extension-host`)
  with the hardened runtime, which is already on. `scripts/make-dmg.sh` then
  signs, notarizes and staples the disk image; it already takes
  `SIGN_IDENTITY` and `NOTARY_PROFILE`. Check the result with
  `spctl --assess` and `stapler validate`.
- **First notarized build.** Fix whatever Apple flags; the extra
  programs inside the app are the usual suspects. Sparkle's helpers are
  already re-signed with the app's certificate and the hardened runtime.
- **CI publishes updates too,** once it notarizes: the update key and a
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

- **Fresh user account:** download from GitHub like a stranger would.
  Then go through Gatekeeper (it must open without warnings), the welcome,
  importing from Transmission and qBittorrent, a magnet link and a .torrent
  file, the VPN, extensions, notifications, start at login, quitting and
  relaunching, and uninstalling.
- **Intel,** on 1 October 2026, under Rosetta on the owner's Mac.
  OrbTorrent Dev's universal build ran as Intel, the engine too, and the
  engine connected and seeded. All 167 tests passed as Intel as well as on
  Apple silicon, after one fix: under Rosetta, extensions' CPU limit let them
  run about 42 times too long, because `mach_timebase_info` reports Intel's
  clock ticks while CPU times stay in Apple silicon's. It now reads the
  hardware's own (`hw.tbfrequency`), which is right on both.
- **Updating:** install beta 1, publish beta 2, and confirm it updates
  without asking for any permission or Keychain access again.
- **Daily use:** the owner's daily app becomes the signed release build
  for a few days. (You)

## 6. Going public

- **Ready to go public,** on 1 October 2026. Making the repo public now
  needs nothing else:
  - The build workflow builds every push and pull request once the repo is
    public, and skips them while it's private, since macOS runners use a
    private repo's free minutes ten times as fast (`.github/workflows/build.yml`).
  - The owner's account details are out of this file and out of the history:
    every commit was rewritten without them, and with GitHub's private address
    for the owner instead of their Gmail. The repo was then deleted and created
    again, so GitHub no longer has the old commits either. The old history is
    kept in a bundle on the owner's Mac.
  - Contribution rules in [CONTRIBUTING.md](CONTRIBUTING.md): contributions
    come in under the licence of the code they change (GPL-3.0-or-later, MIT
    for the SDK), with no contributor licence agreement, so a closed "Pro"
    version of the app could never include them. [SECURITY.md](SECURITY.md)
    takes security reports privately at `help@orbtorrent.com`.
  - Issue forms for problems and ideas, and a pull request template.
  - The README says the name OrbTorrent and the orb icon aren't covered by the
    GPL (its section 7(e)), so forks must use their own.
- **The website** at `orbtorrent.com`, built on 2 October 2026: the
  homepage, download, switch, extensions, FAQ, privacy and press pages, and
  the docs, on Cloudflare (Workers static assets, `website/`), with
  Cloudflare Web Analytics and downloads counted, and an email sign-up for
  1.0 (website/AGENTS.md). Deployed with the beta.
- **Public beta:** make the repo public, so its releases' disk images can
  be downloaded (You), then a GitHub release, posted on r/macapps, quietly.
  Then fixes, shipped through the updater. See [LAUNCH.md](LAUNCH.md).
- **1.0,** the big launch, at least 30 days after the beta's r/macapps
  post, since r/macapps allows one a month. Everything about it is in
  [LAUNCH.md](LAUNCH.md).
- **Homebrew.** From beta 1, our own tap, `orbtorrent/homebrew-tap`:
  `brew install orbtorrent/tap/orbtorrent`. The cask comes from
  `scripts/homebrew-tap.sh`, tested on 2 October 2026 by installing,
  `livecheck` and uninstalling a local build, and
  `.github/workflows/homebrew.yml` updates it as each release is published,
  pushing with a deploy key of the tap. The official cask, for plain `brew
  install orbtorrent`, needs a popularity bar and a pass from Gatekeeper, so
  it comes after launch.

## After 1.0

- VPN partner links, clearly labelled, and only for VPNs that work with
  OrbTorrent's port forwarding (Proton VPN, Private Internet Access, AirVPN).
- A paid iPhone companion app: remote control, and a notification when a
  download finishes.
- GitHub Sponsors, and a Sponsor link in the About window.
- The rest of [ROADMAP.md](ROADMAP.md).
