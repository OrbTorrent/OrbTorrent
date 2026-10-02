# Roadmap

What to build next, ranked by how much torrent users ask for it and how well it
fits OrbTorrent. Researched on 27 September 2026 from the most-upvoted feature
requests on qBittorrent's and Transmission's GitHub trackers, GitHub stars on
the tools people add to their clients, Hacker News threads, recent news and
what competing Mac apps offer. Upvote counts are 👍 reactions on the issue at
that date.

"Engine" says whether the bundled qBittorrent 5.2.3 engine already does the
work, so OrbTorrent only needs settings and interface, or whether OrbTorrent has
to build it. Preference names are the engine's `app/setPreferences` keys.

What's left before the first public release is in [RELEASE.md](RELEASE.md).

## Build first

Heavily requested, and together they'd set OrbTorrent apart from every other
Mac client.

- [x] **Disk-space guard.** Warn in the add confirmation when a download
  won't fit, pause downloads before the disk fills, and resume them when space
  frees up. Today a large download just fails partway through.
  - Demand: qBittorrent's #1 open request, "Prevent starting new download when
    disk space is insufficient" ([#10645](https://github.com/qbittorrent/qBittorrent/issues/10645),
    107 👍), and "Pause all downloads when free space is below XX MB"
    ([#10098](https://github.com/qbittorrent/qBittorrent/issues/10098), 29 👍).
    The new Mac client Current leads with a storage budget ("Smart Cleanup").
  - Engine: no. OrbTorrent checks free space itself. Moderate.

- [x] **Download only through a VPN.** One setting ties OrbTorrent to the VPN's
  network connection, so it stops downloading if the VPN drops instead of
  falling back to the normal connection. It finds VPNs that apps run, and ones
  that route all traffic without becoming the Mac's primary connection, as
  Tunnelblick and `wg-quick` do.
- [x] **VPN port forwarding.** Keep the listening port in step with a VPN that
  forwards a changing port (ProtonVPN's NAT-PMP port forwarding), which people
  do today with background scripts. Also standard NAT-PMP gateways (hide.me),
  Private Internet Access, and a port reserved in the VPN account (AirVPN,
  Windscribe). Tested end to end against a
  WireGuard server with a ProtonVPN-style NAT-PMP gateway: port in use about
  2 seconds after connecting, a peer outside reached the engine through it,
  renewals every 45 seconds, a new port mid-connection and after reconnecting,
  and a gateway that stops forwarding (your own port comes back once the
  mapping lapses). Also a trackerless magnet over the VPN's DHT, a download
  cut off mid-way and resumed, the setting switched on mid-download (existing
  connections are dropped), and the engine crashing on the VPN. With ProtonVPN
  Free: recognised by name, cut off within 0.2 s when it disconnects, and "No
  port forwarded" (Free has none). Also real sleep and wake, Wi-Fi dropping and
  returning, and a bare `wg-quick` tunnel with no macOS VPN entry. Against
  miniupnpd, a standard NAT-PMP gateway: it refuses ProtonVPN-style requests,
  so OrbTorrent asks for its own port instead, and takes an offered port on
  both sides when its own is taken. With Private Internet Access (OpenVPN, no
  macOS VPN entry): found by its routes, its forwarded port read from piactl,
  a peer on the internet connected in through PIA's server, cut off within a
  second when PIA disconnects, and followed a region change. Not yet tried:
  port forwarding on ProtonVPN's own servers (paid plan). OrbTorrent asks
  exactly as Proton's documented client and gluetun do (public address, then
  UDP and TCP), and tells Proton users how to turn port forwarding on.
  - Demand: Transmission's #4 open request, "Bind to an interface"
    ([#338](https://github.com/transmission/transmission/issues/338), 58 👍);
    qBittorrent [#19285](https://github.com/qbittorrent/qBittorrent/issues/19285) (40 👍),
    [#20855](https://github.com/qbittorrent/qBittorrent/issues/20855) (24 👍) and
    [#12596](https://github.com/qbittorrent/qBittorrent/issues/12596) (20 👍).
    Port-sync scripts include a Mac-only one,
    [proton-port-sync](https://github.com/deecypher/proton-port-sync).
  - Engine: binding yes (`current_network_interface`,
    `current_interface_address`). Port sync no: OrbTorrent asks the VPN gateway
    over NAT-PMP and sets `listen_port`. Small.

- [x] **Fake-download check.** Built as the first official extension, on a new
  extension system (see [the extension docs](https://orbtorrent.com/docs/extensions) and
  [the design](docs/extensions-design.md)). Before any of a download arrives,
  the Fake Download Check holds one that contains a program disguised as a
  video, a film with a program or installer in it, or a video locked in an
  archive with a password file. It warns about a film far too small for its
  quality, `.wmv`-only video, links to download elsewhere, and a film with no
  video. It runs in the add confirmation (Download becomes Download Anyway), or,
  when downloads start right away, OrbTorrent adds the download so the engine
  stops it the moment its file list arrives, runs the checks, then starts it or
  holds it with a notification. VirusTotal Scan is the second official
  extension, for finished downloads. Tested against the engine: a fake film
  held, a clean one started, a magnet link stopped at its file list, checked
  and started, and hooks run on a finished download.
  - Demand: fake movie torrents are in the news. The MovieReaper campaign
    spread through a compromised torrent site in August 2026, and a fake
    "One Battle After Another" release hid malware in its subtitles. No
    mainstream client warns about this.
  - Engine: skipping files by pattern yes (`excluded_file_names_enabled`,
    `excluded_file_names`). Downloaded files already get the quarantine flag
    (`mark_of_the_web`). The warning is OrbTorrent's own. Small. The add
    confirmation already has the file list for `.torrent` files, and for magnet
    links once their peers send it (`torrents/fetchMetadata`).

- [x] **Speed up slow torrents.** "Find more peers for public torrents", on by
  default, adds the 20 trackers of ngosang's "best" list to public torrents,
  after their own and each in a tier of its own. OrbTorrent downloads the list
  once a day while the setting is on, keeps the last good copy, and ships with
  one. It leaves out anything that isn't a plain announce address on the
  internet. It doesn't use the engine's own
  `add_trackers_from_url_enabled`: that adds the trackers to a magnet link
  before it's known to be private, and never takes them off. OrbTorrent adds
  them once a torrent is known to be public, or straight away to a magnet
  link whose trackers carry no personal key (a private tracker's address has
  one), and takes them off if it turns out private. It remembers what it
  added, so trackers that drop off the list, or all of them when the setting is
  turned off, come off again, and one taken off by hand stays off. Magnet links
  in the add confirmation are looked up with the trackers too. Tested against
  the engine: a private `.torrent` and a magnet with a passkey tracker left
  alone, a trackerless magnet and a paused download given the list, all taken
  off and put back by the setting.
  - Demand: the two lists people paste in by hand,
    [ngosang/trackerslist](https://github.com/ngosang/trackerslist) (55k ⭐) and
    [XIU2/TrackersListCollection](https://github.com/XIU2/TrackersListCollection)
    (32k ⭐), have more stars than qBittorrent itself (40k ⭐). qBittorrent's
    request for it had 53 👍 before shipping
    ([#6865](https://github.com/qbittorrent/qBittorrent/issues/6865)).
  - Engine: yes (`add_trackers_from_url_enabled`, `add_trackers_url`). Small.

## Next: strongly requested, bigger jobs

- [ ] **Play while downloading.** A Play button downloads the video in order,
  first and last pieces first, and opens it in IINA (or another player) once
  enough has arrived.
  - Demand: "Download in sequential order for new torrents by default"
    ([#164](https://github.com/qbittorrent/qBittorrent/issues/164), 47 👍) and
    "download first and last pieces first" by default
    ([#9746](https://github.com/qbittorrent/qBittorrent/issues/9746), 59 👍).
    [WebTorrent Desktop](https://github.com/webtorrent/webtorrent-desktop)
    (10k ⭐) is built around this. [IINA](https://github.com/iina/iina) has
    46k ⭐.
  - Engine: in-order download and first/last pieces yes, and OrbTorrent already
    uses them. Deciding when enough has arrived and opening the player is ours.
    Moderate.

- [ ] **Remote control and automation.** An opt-in "Allow remote access on my
  network", with a password, so iPhone remote apps and Sonarr/Radarr can use
  OrbTorrent. Later, OrbTorrent could control a qBittorrent running on a NAS or
  seedbox. Needs careful security: off by default, local network only, strong
  password.
  - Demand: "Remote session/thin client"
    ([#5191](https://github.com/qbittorrent/qBittorrent/issues/5191), 65 👍);
    Transmission's "macOS client should be able to connect to remote sessions"
    ([#717](https://github.com/transmission/transmission/issues/717), 24 👍).
    People pay for iPhone apps that only control qBittorrent
    ([Helmarr](https://helmarr.com/qbittorrent/), [BitRemote](https://bitremote.app/)).
    [Sonarr](https://github.com/Sonarr/Sonarr) (16.6k ⭐) and
    [Radarr](https://github.com/Radarr/Radarr) (14.4k ⭐) expect qBittorrent's API.
  - Engine: yes, it is qBittorrent's API (`web_ui_address`, `web_ui_port`).
    Moderate, mostly for the security work.

- [ ] **Smarter seeding.** Plain-language seeding choices, such as "until ratio
  1", "for a week" or "only while few others seed it", with priority for
  torrents that have few other seeders.
  - Demand: qBittorrent's #2 open request, "Prefer seeding torrents with a low
    number of available seeds"
    ([#9063](https://github.com/qbittorrent/qBittorrent/issues/9063), 95 👍), and a
    "Minimum Seeds" share limit
    ([#18614](https://github.com/qbittorrent/qBittorrent/issues/18614), 48 👍).
    Current leads with "Smart Seed" policies.
  - Engine: ratio and time limits yes (`max_ratio`, `max_seeding_time`,
    `max_inactive_seeding_time`). Rarity-based seeding is ours. Moderate.

- [ ] **Block leeching clients.** Ban peers from clients known to download
  without uploading back, such as Xunlei, and peers that claim to download more
  than a torrent's size.
  - Demand: qBittorrent's #3 open request, "block a specific client
    (Thunder)" ([#10258](https://github.com/qbittorrent/qBittorrent/issues/10258),
    84 👍), and "ban peers that download more than 100%"
    ([#15788](https://github.com/qbittorrent/qBittorrent/issues/15788), 22 👍).
    It's the main reason for the
    [qBittorrent Enhanced Edition](https://github.com/c0re100/qBittorrent-Enhanced-Edition)
    fork (26.7k ⭐).
  - Engine: banning yes (`transfer/banPeers`). Spotting them is ours: watch
    connected peers' client names. Moderate.

## Quick wins

Cheap, mostly settings the engine already supports.

- [x] **Report a Problem**, in the Help menu and the menu bar's ⋯ menu,
  on 29 September 2026 (see [RELEASE.md](RELEASE.md)). A GitHub issue as
  another way to report comes once the repo is public.
- [ ] **Show speeds in megabits**, the unit internet plans use
  ([#12971](https://github.com/qbittorrent/qBittorrent/issues/12971), 69 👍).
  Display only.
- [ ] **Pause on an iPhone hotspot or Low Data Mode**, and resume on a normal
  network ([#8288](https://github.com/qbittorrent/qBittorrent/issues/8288),
  17 👍; Transmission [#299](https://github.com/transmission/transmission/issues/299),
  12 👍). Ours, with the Network framework's expensive and constrained path
  flags.
- [ ] **Limit how many download at once.** Today everything added runs at the
  same time and splits the bandwidth. Engine: `queueing_enabled`,
  `max_active_downloads`, `max_active_uploads`, `max_active_torrents`.
- [ ] **Slower speed limits to switch to or schedule**, like Transmission's
  turtle button ("Advanced scheduler",
  [#8804](https://github.com/qbittorrent/qBittorrent/issues/8804), 41 👍).
  Engine: `alt_dl_limit`, `alt_up_limit`, `scheduler_enabled`, `schedule_*`,
  `transfer/toggleSpeedLimitsMode`.
- [ ] **Seeding time limit.** Engine: `max_seeding_time_enabled`,
  `max_seeding_time`.
- [ ] **Watched folder:** add any `.torrent` file saved into a folder. Engine:
  `scan_dirs`.
- [ ] **Labels** (Transmission's #5 open request,
  [#79](https://github.com/transmission/transmission/issues/79), 53 👍).
  Engine: categories and tags.

## Nice to have

- [ ] Separate folder for unfinished downloads. Engine: `temp_path_enabled`,
  `temp_path`.
- [ ] Blocklist of bad peers, updated from a web address
  ([#72](https://github.com/qbittorrent/qBittorrent/issues/72), 45 👍). Engine:
  `ip_filter_enabled`, `ip_filter_path`; downloading the list is ours.
- [ ] Create `.torrent` files. Engine: `torrentcreator/*`.
- [ ] Unpack archives when a download finishes. Engine: `autorun_enabled`,
  `autorun_program`, or do it in OrbTorrent.
- [x] Automatic app updates (Sparkle), with What's New. See
  [RELEASE.md](RELEASE.md).

## Official extensions

Researched on 29 September 2026. Each fits the extension system as it is: a
check before a download starts can hold it, a hook after it finishes reports,
and both can reach fixed web hosts and, once a download finishes, fingerprint
its files. "Extension" says which hooks and permissions each needs.

- [ ] **Phone notifications.** When a download finishes, send a message
  through Telegram, Discord, Pushover, ntfy.sh, Bark or Pushcut (which can run
  an iPhone Shortcut). OrbTorrent's own notifications only reach the Mac, and
  people leave it downloading while they're away.
  - Demand: every client has homemade scripts for it:
    [transmission-telegram](https://github.com/pyed/transmission-telegram) (314 ⭐),
    Deluge's [Telegramer](https://github.com/noam09/deluge-telegramer) (155 ⭐),
    Discord plugins for ruTorrent, and qBittorrent requests for Pushover
    ([#17209](https://github.com/qbittorrent/qBittorrent/issues/17209)) and
    webhooks ([#16520](https://github.com/qbittorrent/qBittorrent/issues/16520)).
    The general push tools have more stars than most torrent clients:
    [ntfy](https://github.com/binwiederhier/ntfy) (34.5k ⭐) and
    [Apprise](https://github.com/caronc/apprise) (17.4k ⭐). qBittorrent has
    email on completion built in, and Sonarr and Radarr each ship about 20
    notification services.
  - Extension: an `afterFinish` hook. Each service is a fixed host
    (`api.telegram.org`, `discord.com`, `api.pushover.net`, `ntfy.sh`, …) and
    tokens go in the Keychain as `password` settings. Small. It can't say that
    a download was held or what other checks found, since extensions don't see
    each other's results: that needs OrbTorrent to pass those events on.
    Self-hosted ntfy or Gotify needs a host the user chooses (below).

- [ ] **Release check.** Before a download starts, compare its name with facts
  about the film. A WEB-DL, WEBRip or BluRay of a film with no digital or disc
  release anywhere yet is held ("Still in cinemas: there's no digital release
  yet, so this can't be a real WEB-DL"). CAM and TS get a warning that it's a
  cinema recording. Optionally, a name that matches a scene release but has
  different files or a different size gets a warning.
  - Demand: fake films that claim early access carried malware all through
    2025 and 2026. [Bitdefender](https://www.bitdefender.com/en-us/blog/hotforsecurity/fake-leonardo-dicaprio-film-torrent-agent-tesla-malware):
    "any torrent claiming early access is very likely a trap"; the fake *One
    Battle After Another* spread in December 2025 while the film was in
    cinemas. MovieReaper's was `the odyssey (2026) [1080p] [webrip] [5.1].exe`
    ([Securelist](https://securelist.com/moviereaper-malware-torrent-odyssey-solana/121344/)),
    and no scene release of the film exists. The Fake Download Check catches
    the `.exe`; this also catches a fake that hides its payload in subtitles.
  - Extension: a `beforeStart` hook with network to `api.themoviedb.org`
    (release types 4, digital, and 5, disc; free for non-commercial use with
    attribution, but it needs a key, so OrbTorrent would ship its own), and
    optionally `api.predb.net` (no key; each release's group, date, file count
    and size). Moderate. Hold only when the dates are clear, and otherwise
    warn. A scene database is a brand risk for an official extension, so that
    part can stay out.

- [ ] **Mac app safety.** Warn before it starts when a download of a Mac app
  carries `.command`, `.sh` or `.scpt` "installers", or a `.pkg` in a cracked
  app: the way AMOS gets people to run Terminal commands that turn Gatekeeper
  off. VirusTotal Scan already checks the files once they arrive.
  - Demand: AMOS, spread through cracked Mac apps and fake `.dmg` files, was
    almost 40% of Sophos's macOS protection updates in 2025
    ([Sophos](https://www.sophos.com/en-us/blog/why-amos-matters-the-macos-malware-stealing-data-at-scale),
    [Trend Micro](https://www.trendmicro.com/en_us/research/25/i/an-mdr-analysis-of-the-amos-stealer-campaign.html)).
    No torrent client warns about it.
  - Extension: `beforeStart`, from file names alone, with no network. Small.
    It could be a section of the Fake Download Check.

- [ ] **Complete season and album check.** Warn when a season pack is missing
  episodes, from [TVmaze](https://www.tvmaze.com/api) (no key), or an album is
  missing tracks or is labelled FLAC but holds MP3s, from
  [MusicBrainz](https://musicbrainz.org/doc/MusicBrainz_API) (no key).
  - Demand: moderate. Filling gaps is much of why people run
    [Sonarr](https://github.com/Sonarr/Sonarr) (16.6k ⭐) and
    [Lidarr](https://github.com/Lidarr/Lidarr) (5.7k ⭐), and
    [beets](https://github.com/beetbox/beets) (15.7k ⭐) tags music from
    MusicBrainz.
  - Extension: `beforeStart`, from file names alone, with network to
    `api.tvmaze.com` and `musicbrainz.org`. Nothing to set up. Small to
    moderate.

- [ ] **Film and show info.** What the download is (rating, year, runtime and
  a TMDB link), and whether it's already on a streaming service the user pays
  for in their country.
  - Demand: moderate. [IMDb-Scout-Mod](https://github.com/Purfview/IMDb-Scout-Mod)
    (584 ⭐) adds this to torrent sites, and
    [excludarr](https://github.com/haijeploeg/excludarr) (234 ⭐) exists so
    people don't download what they already stream.
  - Extension: `beforeStart`, with the same TMDB data as the release check, so
    the two could be one extension.

- [ ] **Allowed file types.** The user picks what downloads may contain
  (video, audio, books…), and anything else holds the download.
  - Demand: qBittorrent [#21774](https://github.com/qbittorrent/qBittorrent/issues/21774)
    (13 👍). [Cleanuparr](https://github.com/Cleanuparr/Cleanuparr) (2.6k ⭐),
    started because malicious `.lnk` and `.zipx` downloads got stuck in Sonarr
    and Radarr, keeps allow and block lists its users still add to.
  - Extension: a setting in the Fake Download Check rather than its own. Small.

### What extensions need next

The most-requested automations don't fit yet. Each needs one new ability,
listed by how much it would unlock:

1. **Change the download:** set its label or category, skip files, pause it.
   This gives automatic labels (qBittorrent
   [#11337](https://github.com/qbittorrent/qBittorrent/issues/11337), 30 👍;
   [#5779](https://github.com/qbittorrent/qBittorrent/issues/5779), 21 👍) and
   skipping junk files instead of holding the whole download. It pairs with
   Labels in the quick wins.
2. **Hosts the user chooses, including the local network when they allow
   it:** refreshing Plex or Jellyfin, Sonarr and Radarr, Home Assistant, and
   self-hosted ntfy or Gotify.
3. **Write files:** unpacking ([Unpackerr](https://github.com/Unpackerr/unpackerr),
   1.5k ⭐; built into Deluge and ruTorrent), saving subtitles
   ([Bazarr](https://github.com/morpheus65535/bazarr), 4.3k ⭐) and renaming
   like FileBot.
4. **Read file contents:** media info, and spotting fake FLAC from its sound,
   as ruTorrent's Spectrogram plugin does.
5. **More moments:** when a download stalls (Cleanuparr's main job) or is
   removed ([#7465](https://github.com/qbittorrent/qBittorrent/issues/7465),
   13 👍).

## Not now

- **Built-in torrent search:** legal risk, and search plugins need constant
  upkeep ([#17445](https://github.com/qbittorrent/qBittorrent/issues/17445)).
- **Automatic downloads from RSS feeds:** people who want this use Sonarr and
  Radarr, which remote access (above) supports.
- **WebTorrent and BitTorrent v2 support:** waiting on the engine
  ([#4163](https://github.com/qbittorrent/qBittorrent/issues/4163), 76 👍;
  Transmission [#47](https://github.com/transmission/transmission/issues/47),
  131 👍, and [#458](https://github.com/transmission/transmission/issues/458), 96 👍).
- **I2P anonymous networking:** needs a separate I2P program running.
- **A subtitles extension:** IINA finds subtitles when a video plays, and an
  extension can't save them yet.
- **Checking game repacks or debrid caches:** real demand
  ([fake FitGirl repacks](https://blog.gridinsoft.com/fitgirl-repacks-safe/)),
  but tied to piracy groups, so not for an official extension.

## Competition

A wave of native SwiftUI torrent clients appeared in 2026:
[Current](https://github.com/alanwtom/current),
[Torrent 7](https://github.com/Wonderfall/torrent7),
[Canopy](https://github.com/Djozman/Canopy) and
[Skein](https://github.com/SwiftyLab/Skein). Each had 0–13 GitHub stars on
27 September 2026, and none offers the four "Build first" features.
qBittorrent's most-upvoted request of all time, a dark theme
([#6434](https://github.com/qbittorrent/qBittorrent/issues/6434), 375 👍), comes
free with a native app.

## Sources

- [qBittorrent issues by upvotes](https://github.com/qbittorrent/qBittorrent/issues?q=is%3Aissue+is%3Aopen+sort%3Areactions-%2B1-desc)
- [Transmission issues by upvotes](https://github.com/transmission/transmission/issues?q=is%3Aissue+is%3Aopen+sort%3Areactions-%2B1-desc)
- [Proton VPN port forwarding](https://protonvpn.com/support/port-forwarding)
- [Tom's Guide: bind your VPN to your torrent client](https://www.tomsguide.com/computing/vpns/how-to-bind-your-vpn-to-your-torrent-client-on-windows-and-mac)
- [MovieReaper via a compromised torrent site (PrivacySavvy)](https://privacysavvy.com/news/cybersecurity/itorrents-repository-moviereaper-malware-fake-films)
- [MovieReaper (Hackread)](https://hackread.com/moviereaper-malware-odyssey-torrents-infect-users/)
- [Fake movie torrent hides malware in subtitles (FlatpanelsHD)](https://www.flatpanelshd.com/news.php?subaction=showfull&id=1766132588)
- [qBittorrent Enhanced Edition features](https://github.com/c0re100/qBittorrent-Enhanced-Edition/blob/v4_3_x/README.md)
- [TRaSH Guides: qBittorrent for Sonarr and Radarr](https://trash-guides.info/Downloaders/qBittorrent/Basic-Setup/)
- [RapidSeedbox: how to torrent on iOS](https://www.rapidseedbox.com/blog/how-to-torrent-on-ios)
- [Eltima: best torrent clients for Mac](https://mac.eltima.com/best-torrent-clients-for-mac.html)
- [Setapp: best torrent client for Mac](https://setapp.com/how-to/best-torrent-client-for-mac)
- [Hacker News: WebTorrent Desktop](https://news.ycombinator.com/item?id=11442116)
- [Hacker News: Transmission ported to C++](https://news.ycombinator.com/item?id=28503546)
- [Securelist: MovieReaper](https://securelist.com/moviereaper-malware-torrent-odyssey-solana/121344/)
- [Bitdefender: fake DiCaprio film torrent](https://www.bitdefender.com/en-us/blog/hotforsecurity/fake-leonardo-dicaprio-film-torrent-agent-tesla-malware)
- [TechRadar: Oscars honeypot](https://www.techradar.com/pro/security/a-classic-honeypot-movie-fans-catching-up-on-best-picture-nominees-targeted-by-dangerous-malware-ahead-of-of-oscars-2026)
- [Sophos: why AMOS matters](https://www.sophos.com/en-us/blog/why-amos-matters-the-macos-malware-stealing-data-at-scale)
- [Trend Micro: AMOS via cracked apps](https://www.trendmicro.com/en_us/research/25/i/an-mdr-analysis-of-the-amos-stealer-campaign.html)
- [Cleanuparr](https://github.com/Cleanuparr/Cleanuparr)
- [ruTorrent plugins](https://github.com/Novik/ruTorrent/wiki/Plugins)
- [qBittorrent: external programs how-to](https://github.com/qbittorrent/qBittorrent/wiki/External-programs-How-to)
- [TMDB release dates API](https://developer.themoviedb.org/reference/movie-release-dates)
- [PreDB API](https://predb.net/api-documentation/)
- [IINA: online subtitles](https://github.com/iina/iina/wiki/Download-Online-Subtitles)
