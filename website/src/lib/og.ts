// The image a link to a page shows on social sites and in chats, 1200 × 630,
// drawn when the site is built: paper and ink, with the orb lit on a night
// tile, as the site draws it.

import { readFileSync } from "node:fs";
import { join } from "node:path";
import satori from "satori";
import { Resvg } from "@resvg/resvg-js";

const root = process.cwd();
const file = (path: string) => readFileSync(join(root, path));
const image = (path: string) => `data:image/png;base64,${file(path).toString("base64")}`;
const fonts = [
  { name: "Geist", data: file("node_modules/@fontsource/geist/files/geist-latin-500-normal.woff"), weight: 500 as const, style: "normal" as const },
  { name: "Geist", data: file("node_modules/@fontsource/geist/files/geist-latin-600-normal.woff"), weight: 600 as const, style: "normal" as const },
  { name: "Geist Mono", data: file("node_modules/@fontsource/geist-mono/files/geist-mono-latin-500-normal.woff"), weight: 500 as const, style: "normal" as const },
];
const orb = image("public/press/orbtorrent-orb.png");
const icon = image("public/icon-192.png");

// Satori lays out with flexbox only, so every box is a flex box.
const h = (type: string, style: Record<string, unknown>, ...children: unknown[]) => ({
  type,
  props: { style: { display: "flex", ...style }, children: children.length === 1 ? children[0] : children },
});

export interface Card {
  title: string;
  subtitle: string;
  /** After the name, such as "Docs". */
  section?: string;
}

/** Draws a page's link preview as a PNG response. */
export async function drawCard({ title, subtitle, section }: Card): Promise<Response> {
  const titleSize = title.length > 44 ? 50 : title.length > 30 ? 56 : 66;
  const svg = await satori(
    h("div", { width: 1200, height: 630, position: "relative", background: "#f6f5f1", color: "#131316", fontFamily: "Geist", padding: 40 },
      h("div", { position: "absolute", left: 40, top: 0, bottom: 0, width: 1, borderLeft: "1px dashed rgba(19,19,22,0.18)" }),
      h("div", { position: "absolute", right: 40, top: 0, bottom: 0, width: 1, borderLeft: "1px dashed rgba(19,19,22,0.18)" }),
      h("div", { flex: 1, flexDirection: "column", justifyContent: "space-between", padding: "28px 40px 28px 36px" },
        h("div", { alignItems: "center", gap: 14 },
          { type: "img", props: { src: icon, width: 44, height: 44 } },
          h("div", { fontSize: 30, fontWeight: 600, letterSpacing: -1 }, "OrbTorrent"),
          ...(section ? [h("div", { fontSize: 30, fontWeight: 500, letterSpacing: -0.5, color: "#8b8a85" }, `/ ${section}`)] : []),
        ),
        h("div", { flexDirection: "column", gap: 22, maxWidth: 620 },
          h("div", { fontSize: titleSize, fontWeight: 500, letterSpacing: -2.6, lineHeight: 1.02 }, title),
          h("div", { fontSize: 26, fontWeight: 500, lineHeight: 1.35, color: "#6b6b72" }, subtitle),
        ),
        h("div", { fontFamily: "Geist Mono", fontSize: 17, letterSpacing: 1.2, color: "#6b6b72" }, "ORBTORRENT.COM · FREE AND OPEN SOURCE"),
      ),
      h("div", {
        width: 430, height: 550, borderRadius: 32, overflow: "hidden", position: "relative", alignItems: "center", justifyContent: "center",
        background: "radial-gradient(circle at 50% 110%, #2a55c9 0%, #0f1c4a 38%, #070b1c 62%, #05070f 85%)",
      },
        { type: "img", props: { src: orb, width: 400, height: 400, style: { position: "absolute", left: 15, top: 60 } } },
      ),
    ) as never,
    { width: 1200, height: 630, fonts },
  );
  const png = new Resvg(svg, { fitTo: { mode: "width", value: 1200 } }).render().asPng();
  return new Response(new Uint8Array(png), { headers: { "Content-Type": "image/png" } });
}
