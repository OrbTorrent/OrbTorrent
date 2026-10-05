// 2. The orb lands in a Mac's menu bar, and its panel drops down: live
// downloads, as in the app. "One look tells you how your downloads are doing."

import { cue } from "../cues";
import { h, motionBlur, put, rise, sink, where, words } from "../lib/dom";
import { icon } from "../lib/icons";
import { fx } from "../lib/stage";
import { ease, keys, seg, softOut, spring } from "../lib/time";
import type { Context, Place, Scene } from "./types";

const rows = [
  { name: "kubuntu-26.04-desktop-amd64.iso", size: 5.07, from: 0.52, to: 0.6, left: "1 hr, 44 min left", glyph: "hardDrive" },
  { name: "xubuntu-26.04-desktop-amd64.iso", size: 5.18, from: 0.33, to: 0.39, left: "8 hr, 48 min left", glyph: "hardDrive" },
  { name: "ubuntu-26.04.1-desktop-amd64.iso", seeding: "6.48 GB · Ratio 0.00", glyph: "hardDrive" },
  { name: "2026-09-15-raspios-trixie-arm64.img.xz", seeding: "1.37 GB · Ratio 0.01", glyph: "archive" },
  { name: "Fedora-Workstation-Live-x86_64-44", seeding: "2.85 GB · Ratio 0.00", glyph: "folder" },
] as const;

/** The whip pan out to scene 3, shared with it. */
export const whip = (t: number) => ease.inOutQuart(seg(t, cue.whip - 0.03, cue.whip + 0.45));

export function menubar(ctx: Context) {
  const root = h("div", { class: "scene" });
  const inner = h("div", { class: "s2-inner" });
  root.append(inner);

  // The menu bar, as drawn over the site's opening picture.
  const slot = h("span", { class: "mb-slot" });
  const bar = h(
    "div",
    { class: "menubar" },
    h("span", { class: "mb-menus" }, h("b", {}, "OrbTorrent"), ...["File", "Edit", "View", "Window", "Help"].map((m) => h("span", {}, m))),
    h("span", { class: "mb-status" }, slot, h("span", { html: icon("wifi", 22, 2.2) }), h("span", { html: icon("battery", 28, 1.8) }), h("span", {}, "9:41")),
  );

  // The panel, from the app's menu bar.
  const speedDown = h("span", {}, "2.3 MB/s");
  const panelHead = h(
    "div",
    { class: "panel-head" },
    h("img", { src: "/site/brand/orb-192.webp", class: "panel-orb", alt: "" }),
    h("b", {}, "OrbTorrent"),
    h("span", { class: "panel-speeds" }, h("i", { class: "down", html: icon("arrowDown", 20, 2.6) }), speedDown, h("i", { class: "up", html: icon("arrowUp", 20, 2.6) }), h("span", {}, "0 kB/s")),
  );
  const rowEls: { el: HTMLElement; fill: HTMLElement; detail: HTMLElement }[] = [];
  const list = h("div", { class: "panel-rows" });
  for (const row of rows) {
    const downloading = !("seeding" in row);
    const fill = h("span", { class: "bar-fill" });
    const detail = h("span", { class: "row-detail" });
    if (!downloading) detail.textContent = `Seeding · ${(row as { seeding: string }).seeding}`;
    const el = h(
      "div",
      { class: `panel-row ${downloading ? "is-down" : "is-seed"}` },
      h("span", { class: "row-tile", html: icon(row.glyph as "hardDrive", 30, 1.8) }, h("span", { class: "row-badge", html: icon(downloading ? "clock" : "check", 15, 3) })),
      h("span", { class: "row-text" }, h("b", {}, row.name), h("span", { class: "bar" }, fill), detail),
      h("span", { class: "row-button", html: icon(downloading ? "pause" : "arrowUpRight", 22, 2.4) }),
      h("span", { class: "row-chevron", html: icon("chevron", 20, 2.2) }),
    );
    list.append(el);
    rowEls.push({ el, fill, detail });
  }
  const more = h("div", { class: "panel-more" }, "Show all 14 downloads ", h("span", { html: icon("chevron", 16, 2.4) }));
  const openApp = h("span", { class: "pill" }, h("i", { html: icon("appWindow", 20, 2) }), "Open App");
  const foot = h(
    "div",
    { class: "panel-foot" },
    openApp,
    h("span", { class: "pill" }, h("i", { html: icon("pause", 18, 2.4) }), "Pause All"),
    h("span", { class: "pill" }, h("i", { html: icon("plus", 20, 2.4) }), "Add Link"),
    h("span", { class: "pill round", html: icon("ellipsis", 22, 3) }),
  );
  const panel = h("div", { class: "panel glass-dark" }, panelHead, h("div", { class: "panel-rule" }), list, more, foot);

  // The words on the left.
  const label = h("p", { class: "label label-dot", style: "--dot: #3885ff" }, h("span", {}, "In your menu bar"));
  const title = h("h2", { class: "headline s2-title" });
  const lineA = h("span", { class: "line" });
  const lineB = h("span", { class: "line tone" });
  const lineC = h("span", { class: "line tone" });
  title.append(lineA, lineB, lineC);
  const wordEls = [...words(lineA, "One look tells you"), ...words(lineB, "how your downloads"), ...words(lineC, "are doing.")];
  const labelWrap = h("div", { class: "word" }, label);
  const caption = h("p", { class: "caption s2-caption" }, "The orb fills as they download, and changes colour when something needs you.");
  const copy = h("div", { class: "s2-copy" }, labelWrap, title, caption);

  inner.append(copy, panel, bar);
  ctx.layer.append(root);
  const blurInner = motionBlur(ctx.defs);

  let left = 0;
  const update = (t: number) => {
    const w = whip(t);
    const wv = (whip(t + 1 / 120) - whip(t - 1 / 120)) * 60;
    put(inner, { x: -1920 * w });
    blurInner(inner, wv * 1920 * 0.018);

    put(bar, { y: -56 * (1 - ease.outCubic(seg(t, cue.land - 0.62, cue.land - 0.18))) });

    // The panel drops from the orb with a little spring.
    if (!left) left = Math.min(where(slot, ctx.camera).cx - 300, 1920 - 600 - 28);
    panel.style.left = `${left}px`;
    const drop = spring(t, cue.land + 0.15, 2.4, 0.62);
    panel.style.transformOrigin = `${where(slot, ctx.camera).cx - left}px -20px`;
    // A slow parallax while it's on screen: the words rise, the panel settles.
    const slow = ease.inOutSine(seg(t, cue.land + 0.3, cue.open));
    const push = 1 + 0.03 * slow;
    put(copy, { y: -22 * slow, s: push });
    // Open App: the panel closes as the window opens.
    const close = ease.outQuad(seg(t, cue.open + 0.02, cue.open + 0.22));
    put(panel, { y: -30 * (1 - drop) + 14 * slow - 12 * close, s: (0.9 + 0.1 * drop) * push * (1 - 0.04 * close), o: seg(t, cue.land + 0.15, cue.land + 0.3) * (1 - close) });
    openApp.classList.toggle("is-hover", t > cue.open - 0.18 && t < cue.open + 0.2);
    put(openApp, { s: 1 - 0.06 * Math.sin(Math.PI * seg(t, cue.open - 0.03, cue.open + 0.12)) });
    const open = ease.inOutSine(seg(t, cue.land + 0.17, cue.land + 1.15));
    panel.style.clipPath = open < 1 ? `inset(0 0 ${((1 - open) * 100).toFixed(2)}% 0 round 36px)` : "none";

    rowEls.forEach(({ el, fill, detail }, i) => {
      const row = rows[i];
      const start = cue.rows + i * 0.12;
      const p = softOut(seg(t, start, start + 0.65));
      put(el, { y: (1 - p) * 22, o: seg(t, start, start + 0.35) });
      const grow = softOut(seg(t, start + 0.1, start + 1.3));
      if ("seeding" in row) {
        fill.style.width = `${(grow * 100).toFixed(2)}%`;
      } else {
        const done = row.from * grow + (row.to - row.from) * seg(t, start + 1.3, cue.open);
        fill.style.width = `${(done * 100).toFixed(2)}%`;
        detail.textContent = `Downloading · ${(row.size * done).toFixed(1)} GB of ${row.size} GB · ${row.left}`;
      }
    });
    put(more, { o: seg(t, cue.land + 1.2, cue.land + 1.55) });
    put(foot, { y: 12 * (1 - softOut(seg(t, cue.land + 1.25, cue.land + 1.8))), o: seg(t, cue.land + 1.25, cue.land + 1.55) });
    speedDown.textContent = `${(2.1 + 0.4 * Math.abs(Math.sin(Math.floor(t * 4) * 1.7))).toFixed(1)} MB/s`;

    rise([label], t, cue.land + 0.7, { length: 0.7 });
    rise(wordEls, t, cue.land + 0.85, { stagger: 0.06, length: 0.8 });
    sink([label, ...wordEls], t, cue.open - 0.6, { stagger: 0.02, length: 0.3 });
    const gone = ease.inCubic(seg(t, cue.open - 0.6, cue.open - 0.25));
    put(caption, { y: 16 * (1 - softOut(seg(t, cue.land + 1.75, cue.land + 2.5))) - 24 * gone, o: seg(t, cue.land + 1.75, cue.land + 2.25) * (1 - gone) });
  };

  /** Where the menu bar's orb sits. */
  const slotAt = () => {
    const box = where(slot, ctx.camera);
    return { x: box.cx, y: box.cy };
  };

  const mini = (t: number): Place | null => {
    if (t < cue.land || t > cue.whip + 0.5) return null;
    const { x, y } = slotAt();
    const s = t - cue.land;
    const squash = 0.34 * Math.exp(-s / 0.11) * Math.cos(s * 2 * Math.PI * 6);
    const wv = (whip(t + 1 / 120) - whip(t - 1 / 120)) * 60;
    return { x, y, d: 28, sx: 1 + squash, sy: 1 - squash * 0.8, blur: Math.abs(wv) * 1920 * 0.006 };
  };

  const scene: Scene = {
    from: cue.launch,
    to: cue.whip + 0.55,
    root,
    update,
    effects(t) {
      // Landing: a ripple from the menu bar.
      const p = seg(t, cue.land, cue.land + 0.6);
      if (p > 0 && p < 1) {
        const { x, y } = slotAt();
        fx.ring(ctx.back, x, y, 16 + 90 * ease.outExpo(p), 2.5 * (1 - p), [200, 225, 255], 0.9 * (1 - p), 12);
        fx.glow(ctx.back, x, y, 120, [140, 190, 255], 0.5 * (1 - p));
      }
    },
    stage(t, add) {
      add.wallpaper = keys(t, [[cue.launch + 0.05, 0], [cue.land - 0.1, 1]]) * (1 - seg(t, cue.whip + 0.15, cue.whip + 0.45));
      add.wallpaperX = -1920 * whip(t) - 60 * ease.inOutSine(seg(t, cue.land, cue.whip + 0.2));
      add.wallpaperBlur = Math.abs(whip(t + 1 / 120) - whip(t - 1 / 120)) * 60 * 1920 * 0.012;
    },
  };
  return { scene, slot: slotAt, mini, panel, openApp };
}
