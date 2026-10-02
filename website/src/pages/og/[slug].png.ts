// The link preview of each of the site's own pages. The docs draw theirs in
// og/docs/.

import type { APIRoute, GetStaticPaths } from "astro";
import { drawCard } from "../../lib/og";

const pages: Record<string, { title: string; subtitle: string }> = {
  home: { title: "The torrent app made for your Mac.", subtitle: "Lives in your menu bar, stays on your VPN, and holds fake downloads before they arrive." },
  download: { title: "Download OrbTorrent", subtitle: "Free for macOS 26 or later, on Apple silicon and Intel." },
  extensions: { title: "Every download, checked.", subtitle: "Extensions hold fakes before they arrive, and you can build your own in TypeScript." },
  switch: { title: "Switch from Transmission or qBittorrent", subtitle: "Your downloads and settings come over in one step, progress and all." },
  privacy: { title: "It collects nothing.", subtitle: "Everything OrbTorrent connects to, and why." },
  faq: { title: "Questions, answered.", subtitle: "Is it free? Is it legal? Does it work with my VPN?" },
  press: { title: "Press kit", subtitle: "Facts, descriptions, the icon and screenshots of OrbTorrent." },
  "404": { title: "This page isn't here.", subtitle: "OrbTorrent, the torrent app made for your Mac." },
};

export const getStaticPaths: GetStaticPaths = () => Object.keys(pages).map((slug) => ({ params: { slug } }));

export const GET: APIRoute = ({ params }) => drawCard(pages[params.slug as string]);
