// The link preview of each of the site's own pages. The docs draw theirs in
// og/docs/.

import type { APIRoute, GetStaticPaths } from "astro";
import { drawCard } from "../../lib/og";

const pages: Record<string, { title: string; subtitle: string }> = {
  home: { title: "The torrent app made for your Mac.", subtitle: "Lives in your menu bar, stays on your VPN, and holds fake downloads before they arrive." },
  download: { title: "Download OrbTorrent", subtitle: "Free for macOS 26 or later, on Apple silicon and Intel." },
  extensions: { title: "Every download, checked.", subtitle: "Extensions hold fakes before they arrive, and you can build your own in TypeScript." },
  switch: { title: "Switch from Transmission or qBittorrent", subtitle: "Your downloads and settings come over in one step, progress and all." },
  "utorrent-for-mac": { title: "µTorrent on the Mac: what works now.", subtitle: "Its desktop app stopped with macOS Catalina. A free Mac app, without ads." },
  "qbittorrent-for-mac": { title: "qBittorrent's engine, made for your Mac.", subtitle: "Notarized, in your menu bar, and tied to your VPN. How the two compare." },
  "transmission-for-mac": { title: "Transmission, and what OrbTorrent adds.", subtitle: "Downloads only through your VPN, a menu bar panel, and fakes held." },
  privacy: { title: "It knows nothing about you.", subtitle: "Everything OrbTorrent connects to and counts, and why." },
  faq: { title: "Questions, answered.", subtitle: "Is it free? Is it legal? Does it work with my VPN?" },
  press: { title: "Press kit", subtitle: "Facts, descriptions, the icon and screenshots of OrbTorrent." },
  "how-its-built": { title: "How OrbTorrent is built.", subtitle: "A SwiftUI app around qBittorrent's engine, tied to your VPN, with extensions in a sandbox." },
  "404": { title: "This page isn't here.", subtitle: "OrbTorrent, the torrent app made for your Mac." },
};

export const getStaticPaths: GetStaticPaths = () => Object.keys(pages).map((slug) => ({ params: { slug } }));

export const GET: APIRoute = ({ params }) => drawCard(pages[params.slug as string]);
