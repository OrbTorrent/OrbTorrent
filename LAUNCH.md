# Launch plan

How OrbTorrent goes from a finished, notarized app to people actually using
it: what we say, where we say it, and in what order. Researched on 29
September 2026; rules and contacts were checked on the day, with sources at
the end. [RELEASE.md](RELEASE.md) covers getting the app ready; this file
starts where it ends. "You" marks steps only the owner can do, and "Me" is
Claude. What's done and what's left, in order, is tracked in
[CHECKLIST.md](CHECKLIST.md); this file is the plan behind it. Times are in
Malaysia time (MYT).

## The short version

- **Two launches.** A quiet public beta, to find bugs and gather the first
  users, stars and quotes. Then a loud 1.0, with Hacker News, the press,
  Reddit and social media all in the same day, and the rest spread over two
  weeks.
- **Launch day is a Tuesday.** Show HN at 08:00 MYT (Monday evening in the
  US), then at 22:00 MYT (Tuesday morning in the US) the press articles, the
  email to everyone who signed up, r/macapps and social media.
- **Most of the work comes before.** A notarized app, a website with a video,
  a press page and an email sign-up, our own Homebrew tap, Reddit and Hacker
  News accounts with some history, and press pitched two to three weeks ahead
  under an embargo.
- **Day one is a pulse, not the whole thing.** Of Show HN posts, the median
  gets 2 points and 50 points is the top 6%. For projects on GitHub, 92% of
  the stars a Show HN brings arrive within 48 hours. What keeps OrbTorrent
  growing afterwards is the long tail: the lists, directories, search pages and
  "best torrent app for Mac" articles it gets into, and people telling each
  other.

## 1. What we're launching

**OrbTorrent: a native Mac torrent app built on qBittorrent's engine. Free,
open source, no ads.**

Who it's for, and why they'd switch:

| Who | What bothers them today | What OrbTorrent does |
|---|---|---|
| Transmission users | Transmission is simple, but can't stay on a VPN or keep a VPN's forwarded port | The same simplicity, in a menu bar app, with both |
| qBittorrent users on a Mac | A powerful engine in an app that doesn't feel like a Mac app | The same engine, as a native SwiftUI app |
| People on Proton VPN, PIA, AirVPN or Windscribe | Proton's own guide says the forwarded port changes on every reconnect and must be typed into the torrent app again; people run background scripts for it | Download only through the VPN, and the port kept in step automatically |
| Anyone who has hit a fake download | Fake films that are really programs, in the news again in August 2026 | The Fake Download Check holds one before any of it arrives |
| People burned by µTorrent | Ads and bundled junk | No ads, no tracking, notarized, open source |

The facts every post, pitch and page draws from:
- A native SwiftUI app with Liquid Glass, for macOS 26, universal (Apple
  silicon and Intel).
- qBittorrent's engine (libtorrent) underneath: µTP, DHT, PeX, encryption.
- Lives in the menu bar, with a full library window.
- Download only through a VPN, with automatic port forwarding for Proton VPN,
  Private Internet Access, AirVPN, Windscribe and hide.me.
- Fake Download Check and VirusTotal Scan, as extensions anyone can write more
  of in TypeScript.
- Import from Transmission or qBittorrent in one step, with progress and
  settings.
- "Find more peers for public torrents", disk-space guard, download in order.
- Signed automatic updates, and What's New after each one.
- Free and GPL-licensed. No account, no ads, no tracking: only anonymous counts, without an ID.

How we talk about it:
- **Respect the others.** Transmission 4.1 (January 2026) and qBittorrent 5.2
  (May 2026) are good, active projects, and OrbTorrent runs on qBittorrent's
  engine. Never "X is dated" or "X is ugly". Say what OrbTorrent does, and let
  people compare. Hacker News and Reddit punish bashing.
- **Only legal torrents** in every screenshot, video and example: Linux
  images, the Internet Archive, Blender's open films. Never name a piracy site.
  r/macapps bans piracy talk, Mac news sites steer clear of it, and the paid
  iPhone companion needs App Store approval later. Apple allows remote
  controls for torrent apps (such as qRemote for qBittorrent), not torrent
  apps themselves, so the brand has to look like what it is: a legitimate tool.
- **Plain and specific,** not marketing. What it does, how it's built, what
  it doesn't do yet.
- **No paid plans at launch.** "Free, open source, no ads" is the story.

## 2. Ready before 1.0

None of the loud launch happens until all of these are true:

- **Notarized and stapled,** and opens on a fresh Mac with no warning.
  Homebrew also requires this: since September 2026 it disables casks that
  fail Gatekeeper. (RELEASE.md, section 4)
- **Updates proven:** a beta has updated itself to the next one on other
  people's Macs, without asking for permissions again.
- **Importing tested** from Transmission and qBittorrent in a fresh user
  account. It's where switchers start.
- **Port forwarding tried on a paid Proton VPN plan.** It's a headline
  claim, and so far it's tested against a Proton-style gateway, not Proton's
  own servers. Until then, the launch copy says "Proton-style NAT-PMP" rather
  than naming Proton.
- **The repo is public,** with a README that opens with a short video or
  GIF, the download and the `brew install` line. Its clean history, issue
  forms and contribution rules are ready. (RELEASE.md, section 6)
- **The engine's source is easy to find:** each release says which
  qBittorrent, libtorrent and Qt versions it contains and links the build
  scripts, as their licences ask. CI writes this into every release's notes
  (`scripts/engine-notes.sh`), with the sources attached.
- **Screenshots show a full library,** 20 or so downloads. Hacker News
  criticised another torrent app's Show HN for showing only two or three at a
  time.
- **Answers ready** for the questions in section 7.

## 3. What to make

- **The website, orbtorrent.com,** on Cloudflare (Workers static assets)
  with Cloudflare Web Analytics (no cookies):
  - the one-line pitch, a 30 to 60 second video, and Download next to
    `brew install orbtorrent/tap/orbtorrent`;
  - screenshots in light and dark, the features, requirements (macOS 26), and
    a calm, factual comparison with Transmission and qBittorrent;
  - privacy, and how to uninstall;
  - an FAQ: Is it safe? Is it legal? Why is it free? Why macOS 26?
  - an email sign-up, "Hear about big releases", in the footer, confirmed by
    email, without tracking, and on the privacy page (built 2 October 2026;
    the 1.0 email itself goes through a newsletter service, CHECKLIST.md §8);
  - pages people search for: "µTorrent for Mac", "qBittorrent for Mac",
    "Transmission for Mac", a guide to magnet links, and a how-to, "Port
    forwarding with Proton VPN on a Mac", which answers a real, recurring
    question. [SEARCH.md](SEARCH.md) has the research, the numbers and the
    order.
- **A press page, orbtorrent.com/press,** open to everyone:
  - a fact sheet: name, version, price (free), macOS 26 or later, universal,
    GPL, developer, website, contact;
  - a short and a long description;
  - 6 to 10 screenshots, the icon at full size, the video;
  - a few lines about you, with a photo;
  - how to uninstall.
- **`press@orbtorrent.com`,** forwarding like help@, so press mail stands
  out.
- **The video** (you record it; I can script it). 30 to 60 seconds: a
  magnet link opening, the menu bar panel, the VPN cutting off and coming
  back, a fake download being held, the import. Also cut as a GIF for the
  README. (You)
- **A technical write-up,** "How OrbTorrent is built": a SwiftUI app
  driving qBittorrent's engine, the extension sandbox, and signed updates
  through Sparkle and a Cloudflare Worker. It's what developer newsletters,
  Lobsters and the Show HN first comment can link to.
- **Our own Homebrew tap,** `github.com/orbtorrent/homebrew-tap`, so `brew
  install orbtorrent/tap/orbtorrent` works from day one. The cask is written
  and tested (`scripts/homebrew-tap.sh`), and CI updates it as each release
  is published. The official Homebrew cask comes later (section 4).
- **Hold the handles:** (You)
  - Bluesky: `@orbtorrent.com`, set by a DNS record on Cloudflare, which
    also shows it's the real one;
  - Mastodon: `@orbtorrent@indieapps.space`, a server only for indie apps;
    your own account on mastodon.social or iosdev.space;
  - X and Threads: `@orbtorrent`;
  - YouTube: `@orbtorrent`, for the video.

## 4. Timeline

The dates depend on Apple. As a guide: Apple approves in October, signed
builds by early November, the beta in November, and 1.0 in January.

1.0 is at least 30 days after the beta's r/macapps post, because r/macapps
allows one post per developer every 30 days. Avoid US Thanksgiving (26
November 2026), 20 December to 5 January, and the weeks of Apple events and
big macOS releases. **Suggested: Tuesday 12 January 2027.** The 19th works
too, but its Show HN would go up on the evening of a US holiday.

Launch-day times below are for US winter time (November to March). In US
summer time, everything US-based comes an hour earlier in MYT.

### Now, while Apple reviews

- Hold the handles (section 3). (You)
- **Reddit:** from your personal account, take part in r/macapps and
  r/swift for real: answer questions, especially Mac and VPN port-forwarding
  ones. r/macapps needs 10 karma earned in r/macapps before you can promote
  anything there. r/swift needs an account at least 60 days old, and
  self-promotion under 5% of what you post. (You)
- **Hacker News:** comment now and then from the account you'll post
  with, so it isn't brand new on the day. New accounts show in green for their
  first two weeks. (You)
- **AlternativeTo:** make an account now. New accounts wait before they
  can suggest apps, and free review can take a long time. (You)
- **Show the work in progress** once or twice a week on Bluesky, Mastodon
  and X: a short clip of the orb, the menu bar, the VPN cut-off, the Fake
  Download Check. Each post points to the email sign-up. (You post; I can
  help write)
- The website, press page, email sign-up and Homebrew tap. (Me; you
  review)
- The technical write-up. (Me; you review)

### The beta (quiet)

- Beta 1 on GitHub, the website's Download button and the Homebrew tap
  switched on.
- **Audit the live website,** once it's deployed. (Me)
  - Lighthouse, on mobile and desktop, for each kind of page: the homepage,
    download, extensions, FAQ, the docs' home and a long docs page.
  - SEO: the sitemap submitted to Google Search Console and Bing Webmaster
    Tools, the structured data checked with validator.schema.org and
    Google's Rich Results Test, link previews on X, Bluesky and Slack,
    canonical addresses and robots.txt.
  - Performance: `CF-Cache-Status: HIT` on a second visit, Brotli
    compression, load times from the US and Europe as well as Malaysia, and
    after a few days, Core Web Vitals from real visits in Web Analytics.
  - That each page loads the analytics script once, and the Download button
    gives the disk image and is counted by `website/stats.sh`.
- **Tell a few people:**
  - the email list;
  - r/macapps, as a request for feedback. Title starts with `[OS]` (open
    source), with the Free flair and their developer post template (PCP). This
    starts the 30-day clock;
  - your Bluesky, Mastodon and X.
  - No Hacker News, press, Product Hunt or GitHub lists yet. (You post)
- **Collect:**
  - bugs, fixed through the updater;
  - the questions people ask, which become the FAQ;
  - quotes from happy users, used with their permission;
  - stars.

### Two to three weeks before 1.0

- **Pitch the press,** with a link to the notarized beta, the press page
  and an embargo: "Please don't publish before Tuesday <date> at 9:00 US
  Eastern (22:00 MYT)". (You send; I draft)
  - Keep each email under 150 words, personal, and in plain text: the
    problem, how OrbTorrent is different, why you built it, and links. Use the
    subject line TidBITS asks for, which works everywhere: `PITCH: OrbTorrent
    – a native Mac torrent app on qBittorrent's engine`.
  - Not on a Monday, and not on an Apple event day.
  - Follow up once, about a week later, as a short reply to the first email,
    with something new. Never mention that other sites are covering it.
- **Pitch the newsletters** (section 5).
- **Write every launch post in advance:** the Show HN title and first
  comment, the r/macapps post, the r/apple Sunday post, the r/SideProject
  story, and the social posts. (Me; you review)
- **A final check:** a fresh download from the website on a clean Mac,
  the feed, help@ and press@. (Me)

### Launch day (a Tuesday)

| MYT | US Eastern | What |
|---|---|---|
| 08:00 | Mon 19:00 | **Show HN**, linking the GitHub repo (stars also count towards Homebrew and GitHub Trending). Your first comment goes up straight away. In an analysis of 14 years of Show HN posts, US evening, around 00:00 UTC, is when good posts face the least competition, and it's daytime for you. (You) |
| 08:00 to 12:00 | evening | Answer every comment within minutes. Never ask anyone to upvote: Hacker News spots voting rings and buries the post. (You) |
| 22:00 | Tue 09:00 | The press embargo lifts. The email goes to the list. r/macapps post, then Bluesky, Mastodon, X and Threads. (You) |
| 22:00 to 02:00 | morning | Answer everywhere. If someone finds a bug, ship the fix the same day through the updater, and say so in the thread. (Us) |

If the Show HN doesn't take off, don't delete it or post it again. Hacker
News moderators sometimes give good posts a second chance on their own. If
that doesn't happen, the next chance is a real update, months later.

### The two weeks after

- **Days 2 and 3:**
  - r/SideProject: the story of why and how you built it;
  - r/coolgithubprojects and r/opensource;
  - Changelog News (a submission form);
  - Lobsters, only if someone there invites you (the author of a story may
    ask), with the technical write-up.
- **The first Sunday:** r/apple, where developers may promote only on
  Sundays, California time (Sunday 16:00 to Monday 16:00 MYT), and only as a
  text post.
- **Days 7 to 10:**
  - Product Hunt, optional, for a second wave. Launches go up at 00:01
    Pacific, which is 16:01 MYT.
  - The directories and the awesome lists (section 5).
- **Days 10 to 14:**
  - Ask the writers of "best torrent app for Mac" articles to try
    OrbTorrent (How-To Geek, TechRadar, ProPrivacy, All About Cookies).
  - Ask Proton VPN whether their port-forwarding guide, which only covers
    Windows apps, could mention a Mac app that handles it.
- **Once OrbTorrent qualifies:** the official Homebrew cask. The repo must be
  at least 30 days old, and when we submit it ourselves it needs 225 stars,
  90 forks or 90 watchers. If someone else submits it, it's 75 stars, 30
  forks or 30 watchers.

### After that

- Ship updates regularly. What's New tells every user what changed, and one
  day about the iPhone app.
- r/macapps again only for a real update, and at least 30 days apart.
- Post real milestones, such as the first 1,000 Macs, on Indie Hackers and
  social media.
- Keep adding the search pages on the website.

## 5. Where: the full list

### Launch sites

| Where | When | How, and the rules |
|---|---|---|
| [Show HN](https://news.ycombinator.com/showhn.html) | Launch day, 08:00 MYT | Title `Show HN: OrbTorrent – a native macOS torrent app built on qBittorrent's engine`. Must be something people can try, with no sign-up in the way. No landing pages, no asking for votes, don't repost. Neutral title, no superlatives. |
| [Product Hunt](https://www.producthunt.com/launch) | Day 7 to 10, optional | Free. Features products that are useful, new, well made or creative. Don't ask for votes either. |
| [r/SideProject](https://www.reddit.com/r/SideProject/) | Day 2 | Self-promotion is the point, but it has to be a story: what, why, how it's built, what feedback you want. |
| [Lobsters](https://lobste.rs) | Day 2 to 3, if invited | Invitation only. Self-promotion under a quarter of what you post, with the `show` tag. |
| [Indie Hackers](https://www.indiehackers.com) | Later | For milestones, not the launch itself. |

### Reddit

| Subreddit | When | Rules that matter |
|---|---|---|
| [r/macapps](https://www.reddit.com/r/macapps/) (about 239,000 members) | The beta, then 1.0 at least 30 days later | 10 karma earned in r/macapps first. Developers use the PCP template and need approval. One post per developer every 30 days. `[OS]` title prefix for open source, and the Free flair. Disclose that you made it. No short links, affiliate links or piracy. |
| [r/apple](https://www.reddit.com/r/apple/) | The first Sunday after launch | Developers only, Sundays only (California time), text posts only. |
| [r/opensource](https://www.reddit.com/r/opensource/) | Day 2 to 3 | Check the sidebar first. |
| [r/coolgithubprojects](https://www.reddit.com/r/coolgithubprojects/) | Day 2 to 3 | Self-promotion allowed, open-source projects do best. Title format reportedly `[Project] OrbTorrent – what it does`; check the sidebar. |
| [r/swift](https://www.reddit.com/r/swift/) (about 141,000 members) | With the technical write-up | Account at least 60 days old, self-promotion under 5% of your activity, and flair required. |
| [r/ProtonVPN](https://www.reddit.com/r/ProtonVPN/) and [r/PrivateInternetAccess](https://www.reddit.com/r/PrivateInternetAccess/) | Ongoing | Answer port-forwarding questions where OrbTorrent is the answer, and say you made it. Check each one's rules before any post of your own. |
| [r/MacOS](https://www.reddit.com/r/MacOS/) | Rarely | No general allowance for promotion. Only as part of a real discussion. |
| r/Piracy and the like | Never | Let OrbTorrent travel there on its own. |

### Press

Pitch two to three weeks before 1.0, under embargo.

| Who | Contact | Notes |
|---|---|---|
| [MacStories](https://www.macstories.net/about/) | viticci@macstories.net, voorhees@macstories.net | In-depth reviews by people who test the app. It's fine to copy both editors. |
| [9to5Mac](https://9to5mac.com/contact) | tips+contact@9to5mac.com | |
| [MacRumors](https://www.macrumors.com/share.php) | tips@macrumors.com | Mostly news, less often apps. |
| [iDownloadBlog](https://www.idownloadblog.com/contact/) | tips@idownloadblog.com | |
| [Cult of Mac](https://www.cultofmac.com/about) | tips@cultofmac.com | |
| [OSXDaily](https://osxdaily.com/contact-os-x-daily/) | osxdailycom@gmail.com | Likes tips and finds. |
| [AppleInsider](https://appleinsider.com/contact) | The form on their contact page | |
| [TidBITS](https://tidbits.com/2026/07/23/how-to-pitch-apps-to-tidbits-in-the-ai-era/) | ace@tidbits.com | Lower priority: older readers, and torrent apps are a crowded category. Plain email only, subject `PITCH: …`, never on a Monday, no press releases. |
| [TorrentFreak](https://torrentfreak.com/contact/) | contact@torrentfreak.com | The torrent world's news site. A small team that writes original stories: lead with the VPN cut-off, the port forwarding and the Fake Download Check. |
| [AppAddict](https://appaddict.app) | The "Submit your app for review" form | Reviews indie, privacy-respecting and open-source Mac apps. |
| How-To Geek, TechRadar, ProPrivacy, All About Cookies | The writers of their "best torrent client" articles | After launch, with the coverage so far, asking them to try OrbTorrent for their next update. How-To Geek's writer calls Transmission their favourite. |

### Newsletters

| Who | How |
|---|---|
| [Indie Dev Monday](https://indiedevmonday.com/faq) | newsletter@indiedevmonday.com: a short intro about you and OrbTorrent. |
| [iOS Dev Weekly](https://suggest.iosdevweekly.com/) | Suggest the technical write-up through the form. |
| [Changelog News](https://changelog.com/news/submit) | Submit 1.0 as news: an open-source Mac app on qBittorrent's engine. |
| [Native Mac Apps](https://nativemacapps.substack.com/) and [MacNative.io](https://macnative.io/submit) | Free submission, for native (not Electron) Mac apps. |
| [Daryl Baxter's App Picks](https://www.darylbaxter.com/) | A short, direct pitch. It's a monthly hand-picked list. |
| MacStories Weekly | Comes with the MacStories pitch. |

### Directories

Submit in the week after launch. They keep bringing people from search for
years.

| Where | Notes |
|---|---|
| [MacUpdate](https://www.macupdate.com/help/submit-app) | Free, Mac only, reviewed by people. |
| [AlternativeTo](https://alternativeto.net) | Free. Suggest OrbTorrent as an alternative to Transmission, qBittorrent, µTorrent, Folx, BiglyBT and Motrix. It's where "µTorrent alternative" searches end up. |
| [MacMenuBar.com](https://macmenubar.com/submit-your-menu-bar-app/) | Menu bar apps only, which OrbTorrent is. |
| [SaaSHub](https://www.saashub.com) | Free. "Alternative to X" pages. |
| [Microlaunch](https://microlaunch.net) | Free. |
| [Peerlist Launchpad](https://peerlist.io/launchpad) | Free, weekly. |

### GitHub lists

Pull requests in the week after launch, once OrbTorrent has some stars and a
release or two.

| List | Stars | Where it goes |
|---|---|---|
| [jaywcjlove/awesome-mac](https://github.com/jaywcjlove/awesome-mac) | 115,000 | Download Management Tools, beside Transmission and qBittorrent, with the open-source and free badges. |
| [serhii-londar/open-source-mac-os-apps](https://github.com/serhii-londar/open-source-mac-os-apps) | 50,600 | Sharing Files. Edit `applications.json`, not the README. Needs a clear README and recent commits. |
| [iCHAIT/awesome-macOS](https://github.com/iCHAIT/awesome-macOS) | 19,300 | Sharing Files, beside Transmission. |
| [jaywcjlove/awesome-swift-macos-apps](https://github.com/jaywcjlove/awesome-swift-macos-apps) | 1,700 | Open-source Swift Mac apps. |
| [open-saas-directory/awesome-native-macosx-apps](https://github.com/open-saas-directory/awesome-native-macosx-apps) | 1,600 | Native Mac apps only. |

### Social

| Where | Account |
|---|---|
| Bluesky | `@orbtorrent.com`, and yours |
| Mastodon | `@orbtorrent@indieapps.space`, and yours on mastodon.social or iosdev.space. Many Mac developers and writers are here. |
| X and Threads | `@orbtorrent`, and yours |
| YouTube | `@orbtorrent`, for the video |

## 6. Launch posts, in outline

**Show HN.** Title as above. The first comment, in your own words:
- who you are, and why you built it (what bothered you about torrenting on a
  Mac);
- how it works: a SwiftUI app driving qBittorrent's engine, which it bundles
  and runs itself; the VPN cut-off; port forwarding over NAT-PMP; extensions
  running in a sandbox;
- what it doesn't do yet (RSS, remote access, search), what's next, and the
  feedback you'd like;
- that it's GPL, has no ads or analytics, and what the update check sends.

Hacker News flags comments that read as written by AI, so write this one
yourself. I can check it.

**r/macapps:** `[OS] OrbTorrent – a native Mac torrent app on qBittorrent's
engine, free and open source`, in their PCP template, saying you made it.

**The press pitch:**

> Subject: PITCH: OrbTorrent – a native Mac torrent app on qBittorrent's engine
>
> Hi <name>, I built OrbTorrent, a free, open-source torrent app for the Mac.
> It runs qBittorrent's engine inside a native SwiftUI app that lives in the
> menu bar. Two things set it apart: it can download only through your VPN and
> keep the VPN's forwarded port in step by itself, which Proton VPN users do
> with scripts today; and it holds fake downloads, such as a "film" that's
> really a program, before any of it arrives. It imports from Transmission and
> qBittorrent in one step.
>
> 1.0 is out on Tuesday <date>, 9:00 US Eastern; please hold coverage until
> then. The notarized build: <link>. Press kit: orbtorrent.com/press.
> macOS 26 or later, free, GPL. Happy to answer anything.
>
> <your name>

## 7. Questions to have answers for

- **Why only macOS 26?** It's built on this year's SwiftUI and Liquid Glass.
  One codebase, done well, rather than two done halfway.
- **Why not help Transmission or qBittorrent instead?** OrbTorrent runs
  qBittorrent's engine unchanged. What it adds is the Mac app around the
  engine, which neither project sets out to build, and engine improvements
  belong upstream.
- **Is it Electron?** No. Swift and SwiftUI.
- **How does it use qBittorrent?** It bundles qBittorrent's engine and runs it
  as a helper, talking to it through qBittorrent's own programming interface
  on the Mac.
- **Does it phone home?** One update check a day. It sends the version and a
  few anonymous counts, never an ID: macOS, Apple silicon or Intel, the week
  it was installed, and how often it quit unexpectedly, so we can count Macs
  and catch a bad release. Nothing about how you use it. Settings shows
  exactly what's sent and turns it off, the address isn't kept, and the code
  is public. Nothing else.
- **Is it safe?** Notarized by Apple, open source, and updates are signed.
- **Is it legal?** Torrenting is legal. What you download is up to you, and
  About says to download only what you have the right to share.
- **Intel?** Yes, universal.
- **RSS, search, remote access, streaming?** Not yet. Streaming ("Play while
  downloading") and remote access are next on the roadmap. Download in order
  exists today.
- **How do I uninstall it?** Drag it to the Trash; its data is in
  `~/Library/Application Support/OrbTorrent`.
- **Will it stay free?** The app stays free and GPL. Anything paid would be
  separate, such as the iPhone companion.

## 8. How we'll know it worked

- **Macs using it each day,** by version: the update checks
  (`updates/stats.sh`). The number that matters most.
- **Downloads:** from the website, by day, the page they started on or the
  site that linked there, and country (`website/stats.sh`). GitHub's download
  counts for each release add the downloads straight from GitHub, and every
  update, since updates download the same disk image.
- **Stars:** towards the Homebrew cask (225) and GitHub Trending.
- **The website:** visits and where they came from (Cloudflare Web Analytics),
  and email sign-ups.
- **Show HN:** 50 points is the top 6%, and 263 the top 1%.
- **Afterwards:** write down what brought people and what didn't, here, for
  the next big release.

## 9. Not doing, and why

- **Asking anyone to upvote,** on Hacker News, Reddit or Product Hunt. They
  detect it and bury the post.
- **Paid ads.** Not needed for a free app, and the audiences above can be
  reached without them.
- **Piracy communities,** for the reasons in section 1.
- **Talking about paid plans** at launch.
- **Setapp and AppSumo:** they're for paid apps.
- **Paid launch directories** (BetaList, now about US$39, and Uneed) and AI
  tool directories: a poor fit for a free Mac app.

## Sources

Checked on 29 September 2026.

- Hacker News: [Show HN guidelines](https://news.ycombinator.com/showhn.html);
  [Show HN by the numbers, 188,000 posts](https://danfking.github.io/blog/2026/04/23/show-hn-by-the-numbers/);
  [Hacker News posting guide](https://syften.com/blog/hacker-news-marketing/);
  [PikaTorrent's Show HN](https://news.ycombinator.com/item?id=36738295).
- Reddit: [r/macapps rules](https://reddifier.com/free-subreddit-analysis-tool/r/macapps);
  [r/swift rules](https://reddifier.com/free-subreddit-analysis-tool/r/swift);
  [r/apple's Sunday rule](https://pulsefox.io/subreddits/apple);
  [r/SideProject](https://www.redditmaster.com/subreddit-rules/sideproject).
- Homebrew: [acceptable casks](https://docs.brew.sh/Acceptable-Casks);
  [notability thresholds](https://github.com/Homebrew/brew/blob/97e5123963a3c9846d6329a9c7ef45964fa4c25f/docs/Acceptable-Formulae.md);
  [casks failing Gatekeeper disabled](https://github.com/orgs/Homebrew/discussions/6482).
- Press: [MacStories](https://www.macstories.net/about/),
  [9to5Mac](https://9to5mac.com/contact),
  [MacRumors](https://www.macrumors.com/share.php),
  [TorrentFreak](https://torrentfreak.com/contact/),
  [TidBITS contact](https://tidbits.com/about/contact/),
  [TidBITS on pitching apps](https://tidbits.com/2026/07/23/how-to-pitch-apps-to-tidbits-in-the-ai-era/),
  [OSXDaily](https://osxdaily.com/contact-os-x-daily/),
  [AppAddict](https://appaddict.app),
  [pitching MacStories](https://www.macstories.net/linked/app-marketing-my-extended-qa-for-paul-hudsons-everything-but-the-code/).
- Lists and directories: [awesome-mac-launch-platforms](https://github.com/macnative/awesome-mac-launch-platforms),
  [open-source-mac-os-apps contributing](https://github.com/serhii-londar/open-source-mac-os-apps/blob/master/CONTRIBUTING.md),
  [MacUpdate](https://www.macupdate.com/help/submit-app),
  [MacMenuBar.com](https://macmenubar.com/submit-your-menu-bar-app/),
  [BetaList pricing](https://launchdirectories.com/directory/betalist).
- Newsletters: [Indie Dev Monday](https://indiedevmonday.com/faq),
  [iOS Dev Weekly](https://suggest.iosdevweekly.com/),
  [Changelog News](https://changelog.com/news/submit),
  [indieapps.space](https://www.indieapps.space/).
- The field: [Proton VPN port forwarding](https://protonvpn.com/support/port-forwarding);
  [Transmission 4.1](https://www.howtogeek.com/transmission-41-makes-my-favorite-bittorrent-client-even-better/);
  [qBittorrent 5.2](https://9to5linux.com/qbittorrent-5-2-open-source-bittorrent-client-released-with-many-new-features);
  [qRemote on the App Store](https://apps.apple.com/us/app/qremote-for-qbittorrent/id6756276747);
  "best torrent client for Mac" roundups by [Setapp](https://setapp.com/how-to/best-torrent-client-for-mac),
  [ProPrivacy](https://proprivacy.com/guides/bittorrent-clients) and
  [All About Cookies](https://allaboutcookies.org/fastest-torrenting-clients).
