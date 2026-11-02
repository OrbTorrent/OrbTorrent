// Facts the whole site uses, in one place.

export const site = {
  name: "OrbTorrent",
  url: "https://orbtorrent.com",
  tagline: "A fast, native torrent app for macOS, powered by qBittorrent.",
  description:
    "OrbTorrent is a free, open-source torrent client for Mac, with no ads. It runs qBittorrent's engine, lives in your menu bar, stays on your VPN and stops fakes.",
  author: "Sanjevi Rau",
  authorUrl: "https://github.com/sanjevirau",
  email: "help@orbtorrent.com",
  repo: "https://github.com/orbtorrent/OrbTorrent",
  releases: "https://github.com/orbtorrent/OrbTorrent/releases",
  issues: "https://github.com/orbtorrent/OrbTorrent/issues/new/choose",
  docs: "/docs",
  extensionDocs: "/docs/extensions",
  contributing: "/docs/contribute",
  security: "https://github.com/orbtorrent/OrbTorrent/blob/main/SECURITY.md",
  roadmap: "https://github.com/orbtorrent/OrbTorrent/blob/main/ROADMAP.md",
  license: "https://github.com/orbtorrent/OrbTorrent/blob/main/LICENSE",
  requirements: "macOS 26 or later",
  /**
   * The newest disk image: the Worker sends it on there, and counts it. On a
   * Mac, the Download buttons start it straight away; see DownloadStarted.astro.
   */
  download: "/download/mac",
  /**
   * Cloudflare Web Analytics' public token for orbtorrent.com, a site added
   * by its hostname; see Analytics.astro and AGENTS.md.
   */
  analytics: "fb3080ee9c314a4a825306aec9a99229",
  engine: { qbittorrent: "5.2.3", libtorrent: "1.2.20", qt: "6.10.3", openssl: "3.6.4", boost: "1.86.0" },
  /**
   * The launch film, in the site's light colours, made in video/ and played
   * by Film.astro. A new cut needs a new file name: browsers keep this one a day.
   */
  film: {
    src: "/film/orbtorrent.mp4",
    seconds: 57,
    made: "2026-10-03",
    description:
      "OrbTorrent's launch film, with music and no speech. It shows the orb and its panel in the menu bar, the library window, a magnet link that starts downloading, the VPN dropping and downloading stopping with it, a fake download held before it starts, and extensions checking every download. It ends on what OrbTorrent is: open source and native, with no ads and no account, and free for macOS 26 or later.",
  },
} as const;

/** The orb's colours, for the page's light and the story's status dots. */
export const tints = {
  active: "#3885ff",
  waiting: "#ff9926",
  paused: "#8d93a8",
  finished: "#33d98c",
  failed: "#ff4040",
} as const;
