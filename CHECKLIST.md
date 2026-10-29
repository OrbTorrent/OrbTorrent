# Launch checklist

Everything left before and after OrbTorrent's launch, in the order it
happens. This is the only place with checkboxes: tick them here.
[RELEASE.md](RELEASE.md) has the details for the app, and
[LAUNCH.md](LAUNCH.md) for getting the word out.

**You** marks what only the owner can do, and **Claude** what Claude does,
for you to review where it says so. Times are Malaysia time (MYT).
Last brought up to date on 29 October 2026.

**Where we are:** the app, the website with its docs and search pages, the
launch film and the extension SDK 1.1.0 are built, and the repo is ready for other developers
and their coding agents. The developer account is ready and the app is
notarized from your Mac, so CI signing and notarizing (section 4) come next.
Meanwhile, prepare what's in sections 2 and 3, and start your own accounts
early: Reddit and Hacker News need weeks of history.

## 1. Done

- [x] **Decisions:** bundle IDs `com.orbtorrent.mac` and `.dev` (since 28
  Oct), the code at `orbtorrent/OrbTorrent`, copyright Sanjevi Rau, version
  1.0 with betas as rising builds. (29 Sep)
- [x] **The name held:** `orbtorrent.com` (renew by hand before 29 Sep 2027),
  the GitHub organisation `orbtorrent`, the npm organisation `orbtorrent`.
  `help@orbtorrent.com` forwards to your Gmail, tested. (29 Sep, 1 Oct)
- [x] **OrbTorrent and OrbTorrent Dev** split, each signed with a
  certificate. (29 Sep)
- [x] **Automatic updates:** signed with a key backed up in your password
  manager, from `updates.orbtorrent.com`, What's New after each one. Updates
  install themselves while OrbTorrent isn't in use. `publish-update.sh` takes
  `--critical`, `--phased` and `--withdraw`. Tested three ways. (29 Sep to
  2 Oct)
- [x] **Anonymous counts** with the update check, with no ID, shown in
  Settings, live on the update feed, and added up by `updates/stats.sh`.
  (2 Oct)
- [x] **In the app:** the About window with acknowledgements and privacy,
  the Help menu with Report a Problem, the welcome, the Fake Download Check
  sharpened, and Intel tested under Rosetta. (29 Sep to 2 Oct)
- [x] **Extension SDK on npm,** published from CI through trusted
  publishing, and building extensions with AI, tested with Claude Code,
  Codex and Cursor. (29 Sep to 1 Oct)
- [x] **Ready to go public:** a clean history, CONTRIBUTING.md, SECURITY.md,
  issue forms, and the name and icon reserved from the GPL. (1 Oct)
- [x] **The website and docs built:** the homepage, download, switch,
  extensions, FAQ, privacy and press pages, the docs, and `llms.txt`, with
  downloads counted and Cloudflare Web Analytics. They go live with the beta.
  (2 Oct)
- [x] **The press page's basics:** the fact sheet, short and long
  descriptions, and six images including the icon. (2 Oct)
- [x] **Screenshots with a full library:** legal downloads only, 14 in the
  press page's library shot and 11 in the README's. (1 to 2 Oct)
- [x] **`press@orbtorrent.com`** forwards to your Gmail, like help@. Send it
  a test from another inbox once. (2 Oct)
- [x] **Extension SDK 1.0.4,** linking the docs on orbtorrent.com. (2 Oct)
- [x] **Extension API 1.1, built and tested:** extensions can add files such
  as subtitles next to a finished download (`files.save`, permission
  `"files": "add"`), read bytes from `fetch`, and ask for a notification.
  Requests now connect to the address OrbTorrent checked, through a relay.
  `AGENTS.md`, the Agent Skill and the docs say up front what extensions
  can't do, and the docs have a subtitles extension as a worked example.
  (3 Oct)
- [x] **"When a download finishes, run",** in Settings › Downloads: your own
  program or script, after the download's checks and not if one failed,
  without a shell. Only you can choose it; the engine's own way stays off.
  The docs have a guide with tested scripts. (3 Oct)
- [x] **Extension SDK 1.1.0 on npm,** ahead of the beta. Until then,
  extensions that use API 1.1 need the build made on 3 Oct or later. (3 Oct)
- [x] **Ready for other developers and their coding agents:** `AGENTS.md` at
  the top of the repo, a pull request template that asks which agent helped
  and whether a person read it, the rules for the community list, and a
  "Propose an official extension" issue form. The comment on changed
  extension permissions now knows `"files": "add"` and works on pull
  requests from forks. (3 Oct)
- [x] **Search research:** what Mac users search for and how many, who
  answers them, and the pages to make, from autocomplete, Bing, forums and
  Semrush ([SEARCH.md](SEARCH.md)). (3 Oct)
- [x] **Search pages,** in [SEARCH.md](SEARCH.md)'s order: the homepage's
  title and description, µTorrent for Mac, qBittorrent for Mac, a guide to
  magnet links, Transmission for Mac, and "kill switch" in the VPN guide. Each
  app page has a fair comparison table, its facts checked first-hand and
  linked, and how to switch. They go live with the site. The FAQ's "Why does
  it need macOS 26?" no longer says "this year's", with macOS 27 out. (3 Oct)
- [x] **The engine's versions in every release's notes,** added by CI:
  qBittorrent, libtorrent, Qt, OpenSSL and Boost with their licences, what
  changed since the release before, and links to the build script, with
  the sources attached. What's New leaves it out. (2 Oct)
- [x] **The Homebrew cask,** written and tested: installed from a local
  build, `livecheck` against a sample of the feed, uninstalled. CI updates
  the tap as each release is published, and `--withdraw` moves it back. The
  download page, the docs and the README show the `brew install` line.
  (2 Oct)
- [x] **The email sign-up,** "Hear about big releases", in the footer of
  every page. Each address gets an email with a link to confirm, and joins
  the list, kept in the EU, only once it's used; unconfirmed ones go after 7
  days. No tracking, a page to unsubscribe, and the privacy page says it all.
  orbtorrent.com sends through Cloudflare as hello@ (which forwards to you),
  signed and with a strict DMARC policy, and a test scored 7.5/10 on
  mail-tester, losing only for links to the site, which isn't live yet.
  The test email reached your Gmail's Primary inbox. (2 Oct)
- [x] **Answers drafted** for the questions people will ask
  ([LAUNCH.md §7](LAUNCH.md#7-questions-to-have-answers-for)).
- [x] **The technical write-up,** "How OrbTorrent is built", at
  `orbtorrent.com/how-its-built`, going live with the site: why it exists,
  qBittorrent's engine built from source and kept private, the VPN cut-off
  and port forwarding, fakes held before they arrive, the extension sandbox,
  signed updates and the orb, with each fact checked against the code,
  excerpts of it, a diagram and a live orb. It's in the footer, `llms.txt`
  and the docs' How OrbTorrent works. (3 Oct)
- [x] **The launch film,** 57 seconds, made from code and cut to its music:
  the orb's first appearance with the tagline, the menu bar, the library, a
  magnet link, the VPN cutting off, a fake held, extensions, and the end
  card. In 1080p and 4K, with a smaller copy for sharing and a poster, in
  `video/out/`. A light version was made to compare. `video/README.md` says
  how to render it, and the music's licence. (3 Oct)
- [x] **The film on the homepage:** "Watch the film" beside the Download
  button opens the light film, on the page's paper, with its sound. Nothing
  of it loads until it's clicked. The Worker answers the byte ranges Safari
  needs, and search engines get its structured data. Tested in Chrome and
  WebKit. (3 Oct)

## 2. Now: Claude

- [ ] **Short clips of the film** for showing the work in progress.

## 3. Now: you

- [ ] **Reddit:** take part in r/macapps and r/swift for real. r/macapps
  needs 10 karma earned there before you can post about OrbTorrent, and
  r/swift an account at least 60 days old.
- [ ] **Hacker News:** comment now and then from the account you'll post
  with, so it isn't new on launch day.
- [ ] **AlternativeTo:** make an account. New accounts wait before they can
  suggest apps.
- [ ] **Hold the handles:**
  - Bluesky `@orbtorrent.com` (Claude adds the DNS record);
  - Mastodon `@orbtorrent@indieapps.space`, and your own account;
  - X and Threads `@orbtorrent`;
  - YouTube `@orbtorrent`, for the film. Its music is in YouTube's Content
    ID, so expect an automatic claim and dispute it with the licence
    (`video/README.md`). Once it's up, Claude links it from the press page,
    for anyone writing about OrbTorrent.
- [ ] **Show the work in progress** once or twice a week once the handles are
  yours: short clips of the orb, the menu bar, the VPN cut-off. Claude can
  help write them.
- [ ] **A few lines about you and a photo,** for the press page.
- [ ] **Read the technical write-up** (`npm run dev` in `website/`, then
  `/how-its-built`), especially its opening, which speaks for you as "I".
  Its date is in `src/pages/how-its-built.astro`: set it to the day it goes
  live.
- [ ] **Try port forwarding on a paid Proton VPN plan.** Until it's tried,
  the launch copy says "Proton-style NAT-PMP" rather than naming Proton.

## 4. Signing and notarization

- [x] **Apple Developer Program,** as an individual with your own Apple
  Account, renewed, with your bank account in App Store Connect. (28 Oct)
- [x] **Developer ID Application certificate,** and notarizing from your
  Mac with an app-specific password. (29 Oct)
- [x] **The first notarized build:** accepted with no issues. (29 Oct)
- [ ] **An App Store Connect API key** for CI to notarize with. (You, with
  Claude)
- [ ] **CI signs and notarizes each release,** with the certificate, its
  password and the API key in GitHub secrets. (Claude)
- [ ] **CI publishes updates too,** with the update key and a Cloudflare
  token that can only write the feed in GitHub secrets. You create the
  token, and Claude does the rest.

Details: [RELEASE.md §4](RELEASE.md#4-signing-and-notarization).

## 5. Before the beta

With the first notarized build:

- [x] **It opens on a fresh Mac with no warning,** checked with `spctl` and
  `stapler`. (29 Oct)
- [ ] **A fresh user account, like a stranger.** Download it from GitHub,
  then go through Gatekeeper, the welcome, importing from Transmission and
  qBittorrent, a magnet link and a .torrent file, the VPN, extensions,
  notifications, start at login, quitting and opening again, and
  uninstalling. (You and Claude)
- [ ] **Your daily app becomes the signed build** for a few days, since 29
  Oct. (You)
- [x] **Your daily app moves to `com.orbtorrent.mac`** with it, with your
  settings and the VirusTotal key. (29 Oct)
- [ ] **Beta 1's release notes:** what's in it and what's counted, linking
  orbtorrent.com/privacy#counts. CI adds the engine's versions. Claude
  drafts and you publish.

## 6. The beta (quiet)

In this order:

- [ ] **Make the repo public.** (You)
- [ ] **Release beta 1:** tag it, CI builds and notarizes it, publish the
  GitHub release, then `publish-update.sh`. (You and Claude)
- [ ] **Homebrew tap live,** before the site, which shows the `brew install`
  line (Claude):
  - create `orbtorrent/homebrew-tap`, public, with a README;
  - add a deploy key that can write to it, and its private half as the
    secret `HOMEBREW_TAP_DEPLOY_KEY`;
  - `gh workflow run homebrew.yml -f tag=v1.0-beta.1`, then
    `brew install orbtorrent/tap/orbtorrent` on a Mac without OrbTorrent.
- [ ] **Deploy orbtorrent.com,** and turn on deploying with each push. That
  needs a Cloudflare token you create, which can also use the site's D1
  database and send email. (Claude)
- [ ] **Try the email sign-up live:** sign up from the footer, confirm, and
  unsubscribe, check the email's icon shows, then mail-tester again, which
  should score about 9.5 once the links work. (Claude)
- [ ] **Audit the live website** (Claude):
  - Lighthouse on mobile and desktop;
  - the sitemap submitted to Google and Bing, the structured data
    validated, link previews and robots;
  - caching, compression and speed from the US and Europe;
  - analytics loading once, and Download counted.

  Details: [LAUNCH.md, the beta](LAUNCH.md#the-beta-quiet).
- [ ] **Report a Problem can open a GitHub issue,** now that the repo is
  public. (Claude)
- [ ] **The Agent Skill** through `npx skills add`, and the docs on
  Context7. (Claude)
- [ ] **Tell a few people** (You). Not Hacker News, the press, Product Hunt
  or the GitHub lists yet.
  - the email list;
  - r/macapps, as a request for feedback: an `[OS]` title, the Free flair
    and their PCP template. This starts the 30-day clock;
  - your own social accounts.

## 7. During the beta, at least 30 days

- [ ] **Beta 2 updates beta 1** on other people's Macs, without asking for
  any permission again. (You and Claude)
- [ ] **Collect** bugs, fixed through the updater, the questions people ask,
  for the FAQ, quotes from happy users (with their permission), and stars.
  (You and Claude)
- [ ] **Watch the counts:** Macs each day, and quits per version
  (`updates/stats.sh`). A version that crashes gets a `--critical` fix.
  (Claude)
- [ ] **Pick the 1.0 date:** a Tuesday at least 30 days after the r/macapps
  post, away from holidays and Apple events. Suggested: Tuesday 12 January
  2027. (You)
- [ ] **Everything in [LAUNCH.md §2](LAUNCH.md#2-ready-before-10) is true:**
  notarized, updates proven, importing tested, Proton tried, the repo public
  with its README, the engine's source in each release, full-library
  screenshots, and answers ready.

## 8. Two to three weeks before 1.0

- [ ] **Pitch the press** under embargo, from the list in
  [LAUNCH.md §5](LAUNCH.md#press). Claude drafts and you send.
- [ ] **Pitch the newsletters**
  ([LAUNCH.md §5](LAUNCH.md#newsletters)). Claude drafts and you send.
- [ ] **Write every launch post in advance:** the r/macapps post, the
  r/apple Sunday post, the r/SideProject story and the social posts. Claude
  drafts and you review. Write the Show HN title and first comment
  yourself, since Hacker News flags text that reads as AI; Claude checks
  them.
- [ ] **How the 1.0 email goes out:** Cloudflare sends only emails like the
  confirmation for now, so a newsletter service sends this one: Resend (free
  up to 1,000 people) or EmailOctopus (free up to 2,500), with tracking off,
  unless Cloudflare supports newsletters by then. `website/newsletter.sh
  export` gives the list, with when each confirmed. The email needs a postal
  address, and the privacy page names the service. (You and Claude)
- [ ] **A final check:** a fresh download from the website on a clean Mac,
  the feed, help@ and press@. (Claude)
- [ ] **Check the comparison pages again:** µTorrent, qBittorrent and
  Transmission, against each app's newest version and site, and update each
  page's "Checked on" date. Once Transmission 4.2 is out with hole punching,
  change the Transmission page, its FAQ answer and the opening of How
  OrbTorrent is built, which say 4.1.3 doesn't have it. (Claude)

## 9. Launch day, a Tuesday

- [ ] **08:00:** Show HN, linking the repo, with your first comment straight
  away. (You)
- [ ] **08:00 to 12:00:** answer every comment within minutes. Never ask for
  votes. (You)
- [ ] **22:00:** the embargo lifts. Email the list, then post on r/macapps,
  Bluesky, Mastodon, X and Threads. (You)
- [ ] **22:00 to 02:00:** answer everywhere, and ship any fix the same day
  through the updater. (You and Claude)

Details: [LAUNCH.md, launch day](LAUNCH.md#launch-day-a-tuesday).

## 10. The two weeks after

- [ ] **Days 2 and 3:** the r/SideProject story, r/coolgithubprojects and
  r/opensource, and Changelog News. Lobsters only if someone invites you,
  with the technical write-up. (You)
- [ ] **The first Sunday:** r/apple, as a text post, between Sunday 16:00
  and Monday 16:00. (You)
- [ ] **Days 7 to 10** (You and Claude):
  - Product Hunt, if you want a second wave;
  - the directories: MacUpdate, AlternativeTo, MacMenuBar.com, SaaSHub,
    Microlaunch and Peerlist;
  - the five GitHub lists in
    [LAUNCH.md §5](LAUNCH.md#github-lists).
- [ ] **Days 10 to 14:** ask the writers of "best torrent app for Mac"
  articles to try it, and ask Proton VPN whether their port-forwarding guide
  could mention a Mac app. (You; Claude drafts)
- [ ] **Write down what brought people and what didn't**
  ([LAUNCH.md §8](LAUNCH.md#8-how-well-know-it-worked)). (You and Claude)

## 11. Later

- [ ] **The official Homebrew cask,** so plain `brew install orbtorrent`
  works. The repo must be at least 30 days old, with 225 stars, 90 forks or
  90 watchers if we submit it ourselves, or 75, 30 or 30 if someone else
  does. (Claude)
- [ ] **Keep going:**
  - regular updates;
  - r/macapps only for a real update, at least 30 days apart;
  - milestones on Indie Hackers;
  - more search pages.

  (You and Claude)
- [ ] **Search, a month after launch:** Google Search Console shows which
  searches find our pages and get clicks. Then check our positions with
  Semrush, and make the next pages ([SEARCH.md](SEARCH.md#after-launch)).
  (Claude)
- [ ] **GitHub Sponsors,** and a Sponsor link in the About window. (You and
  Claude)
- [ ] **Renew orbtorrent.com** before 29 September 2027. Auto-renew is off.
  (You)
- [ ] **npm's trusted publishing again** for both packages, now that the
  code is at `orbtorrent/OrbTorrent`. (You)
- [ ] **After 1.0:** VPN partner links, the iPhone companion, and the rest
  of [ROADMAP.md](ROADMAP.md).
