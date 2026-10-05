// 2b. Open App: the library window opens from the panel's button, over the
// same desktop, as in the press shot. A download is clicked, and the
// inspector looks inside it. "A full Mac window, when you want one."

import { cue } from "../cues";
import { h, motionBlur, put, rise, where, words } from "../lib/dom";
import { icon } from "../lib/icons";
import { cubic, ease, lerp, seg, softOut, spring } from "../lib/time";
import type { Context, Place, Scene } from "./types";
import { whip } from "./s2-menubar";

type Glyph = "hardDrive" | "folder" | "archive";
interface Row {
  name: string;
  glyph: Glyph;
  /** Downloading: its size in GB and how far along it is through the scene. */
  total?: number;
  from?: number;
  to?: number;
  left?: string;
  /** Seeding: its size and ratio. */
  size?: string;
  ratio?: string;
  speed?: string;
}

// The 14 downloads of the panel's "Show all 14 downloads", all legal: Linux
// images, Blender's open films and the WIRED CD.
const rows: Row[] = [
  { name: "kubuntu-26.04-desktop-amd64.iso", glyph: "hardDrive", total: 5.07, from: 0.6, to: 0.63, left: "1 hr, 40 min left", speed: "↓ 1.6 MB/s" },
  { name: "xubuntu-26.04-desktop-amd64.iso", glyph: "hardDrive", total: 5.18, from: 0.39, to: 0.405, left: "8 hr, 44 min left", speed: "↓ 729 kB/s" },
  { name: "ubuntu-26.04.1-desktop-amd64.iso", glyph: "hardDrive", size: "6.48 GB", ratio: "0.00", speed: "↑ 166 bytes/s" },
  { name: "Fedora-Workstation-Live-x86_64-44", glyph: "folder", size: "2.85 GB", ratio: "0.00", speed: "↑ 5 kB/s" },
  { name: "2026-09-15-raspios-trixie-arm64.img.xz", glyph: "archive", size: "1.37 GB", ratio: "0.01" },
  { name: "Tears of Steel", glyph: "folder", size: "571.4 MB", ratio: "0.00" },
  { name: "Sintel", glyph: "folder", size: "129.3 MB", ratio: "0.02" },
  { name: "Big Buck Bunny", glyph: "folder", size: "276.4 MB", ratio: "0.00", speed: "↑ 719 bytes/s" },
  { name: "ElephantsDream", glyph: "folder", size: "27.97 GB", ratio: "0.00" },
  { name: "The WIRED CD - Rip. Sample. Mash. Share", glyph: "folder", size: "56.1 MB", ratio: "0.00" },
  { name: "Cosmos Laundromat", glyph: "folder", size: "220.9 MB", ratio: "0.00" },
  { name: "LibreOffice_26.8.0_MacOS_aarch64.dmg", glyph: "hardDrive", size: "298.8 MB", ratio: "0.00" },
  { name: "debian-13.7.0-amd64-netinst.iso", glyph: "hardDrive", size: "792.7 MB", ratio: "0.00" },
  { name: "archlinux-2026.09.01-x86_64.iso", glyph: "hardDrive", size: "1.61 GB", ratio: "0.03" },
];
const chosen = 5;

const files: [string, string, "image" | "messageSquare" | "film"][] = [
  ["poster.jpg", "36 kB", "image"],
  ...["de", "en", "es", "fr", "it", "nl"].map((code) => [`Tears of Steel.${code}.srt`, "5 kB", "messageSquare"] as [string, string, "messageSquare"]),
  ["Tears of Steel.no.srt", "10 kB", "messageSquare"],
  ["Tears of Steel.ru.srt", "6 kB", "messageSquare"],
  ["Tears of Steel.webm", "571.3 MB", "film"],
];

/** Where the window sits once open, and its size. */
const frame = { x: 280, y: 232, w: 1360, h: 800 };

export function library(ctx: Context, openApp: HTMLElement) {
  const root = h("div", { class: "scene" });
  const inner = h("div", { class: "s2-inner" });
  root.append(inner);

  // The words, above the window.
  const label = h("p", { class: "label label-dot", style: "--dot: #3885ff" }, h("span", {}, "The library"));
  const labelWrap = h("div", { class: "word" }, label);
  const title = h("h2", { class: "headline lib-title-words" });
  const lineA = h("span", {});
  const lineB = h("span", { class: "tone" });
  title.append(lineA, " ", lineB);
  const titleWords = [...words(lineA, "A full Mac window,"), ...words(lineB, "when you want one.")];
  const copy = h("div", { class: "lib-copy" }, labelWrap, title);

  // The sidebar.
  const sideItems = [
    ["inbox", "All Downloads", "14"],
    ["circleArrowDown", "Downloading", "2"],
    ["circleArrowUp", "Seeding", "12"],
    ["circleCheck", "Completed", "12"],
    ["circlePause", "Paused", ""],
  ].map(([glyph, text, count], i) =>
    h("div", { class: `lib-item${i ? "" : " is-current"}` }, h("i", { html: icon(glyph as "inbox", 22, 1.9) }), h("span", {}, text), h("em", {}, count)),
  );
  const sideEnd = [
    h("div", { class: "lib-item lib-ext" }, h("i", { html: icon("puzzle", 22, 1.9) }), h("span", {}, "Extensions")),
    h("div", { class: "lib-speeds" }, h("i", { class: "down", html: icon("arrowDown", 17, 2.6) }), h("span", {}, "2.3 MB/s"), h("i", { class: "up", html: icon("arrowUp", 17, 2.6) }), h("span", {}, "6 kB/s")),
  ];
  const side = h(
    "aside",
    { class: "lib-side" },
    h("div", { class: "lib-side-top" }, h("span", { class: "lib-lights" }, h("i"), h("i"), h("i")), h("span", { class: "lib-round", html: icon("panelLeft", 20, 1.9) })),
    h("p", { class: "lib-section" }, "Library"),
    ...sideItems,
    h("div", { class: "lib-spacer" }),
    ...sideEnd,
  );

  // The list.
  const rowEls = rows.map((row) => {
    const downloading = row.total !== undefined;
    const fill = h("span", { class: "bar-fill" });
    const detail = h("span", { class: "lib-detail" }, downloading ? "" : `Seeding · ${row.size} · Ratio ${row.ratio}`);
    const el = h(
      "div",
      { class: `lib-row ${downloading ? "is-down" : "is-seed"}` },
      h("span", { class: "row-tile lib-tile", html: icon(row.glyph, 24, 1.8) }, h("span", { class: "row-badge", html: icon(downloading ? "clock" : "check", 12, 3.2) })),
      h("span", { class: "lib-text" }, h("span", { class: "lib-top" }, h("b", {}, row.name), h("span", { class: "lib-speed" }, row.speed ?? "")), h("span", { class: "bar" }, fill), detail),
    );
    return { el, fill, detail, row };
  });
  const bar = h(
    "header",
    { class: "lib-bar" },
    h("span", { class: "lib-heading" }, h("b", {}, "All Downloads"), h("span", {}, "14 items · 52.88 GB")),
    h(
      "span",
      { class: "lib-tools" },
      h("span", { class: "lib-group" }, h("i", { html: icon("plus", 22, 2) }), h("i", { class: "lib-sep" }), h("i", { html: icon("chevronDown", 18, 2.2) })),
      h("span", { class: "lib-group" }, h("i", { html: icon("pause", 20, 2) }), h("i", { html: icon("trash", 21, 1.9) })),
      h("span", { class: "lib-group" }, h("i", { html: icon("arrowUpDown", 21, 1.9) }), h("i", { html: icon("chevronDown", 16, 2.2) })),
    ),
  );
  const list = h("div", { class: "lib-list" }, ...rowEls.map((r) => r.el));
  const main = h("main", { class: "lib-main" }, bar, list);

  // The inspector: nothing selected, then Tears of Steel.
  const empty = h(
    "div",
    { class: "lib-empty" },
    h("i", { html: icon("panelRight", 46, 1.6) }),
    h("b", {}, "No Selection"),
    h("span", {}, "Select a download to see its files, peers and details."),
  );
  const orbSlot = h("span", { class: "lib-orb" });
  const buttons = [
    ["pause", "Pause"],
    ["open", "Open"],
    ["folder", "Finder"],
    ["trash", "Remove"],
  ].map(([glyph, text]) => h("span", { class: `lib-button${text === "Remove" ? " is-remove" : ""}` }, h("i", { html: icon(glyph as "pause", 21, 2) }), text));
  const fileEls = files.map(([name, size, glyph]) =>
    h("div", { class: "lib-file" }, h("i", { html: icon(glyph, 22, 1.7) }), h("span", {}, h("b", {}, name), h("em", {}, size)), h("span", { class: "lib-ok", html: icon("check", 13, 3.4) })),
  );
  const detail = h(
    "div",
    { class: "lib-detail-pane" },
    h("div", { class: "lib-item-head" }, orbSlot, h("span", {}, h("b", {}, "Tears of Steel"), h("span", {}, "Seeding · 571.4 MB"), h("span", {}, "↑ 0 kB/s · Ratio 0.00"))),
    h("div", { class: "lib-buttons" }, ...buttons),
    h("div", { class: "lib-tabs" }, ...["Files", "Details", "Peers", "Trackers", "Checks"].map((tab, i) => h("span", { class: i ? "" : "is-on" }, tab))),
    h("p", { class: "lib-count" }, "10 files · 571.4 MB"),
    ...fileEls,
  );
  const inspector = h(
    "section",
    { class: "lib-inspector" },
    h("header", { class: "lib-search-bar" }, h("span", { class: "lib-round", html: icon("panelRight", 20, 1.9) }), h("span", { class: "lib-search" }, h("i", { html: icon("search", 19, 2) }), "Search Downloads")),
    empty,
    detail,
  );
  const win = h("div", { class: "lib" }, side, main, inspector);

  const pointer = h("div", {
    class: "pointer",
    html: '<svg width="40" height="56" viewBox="0 0 20 28"><path d="M2 1.5v21.2l5.2-5 3.3 7.8 3.6-1.5-3.3-7.6h7.1z" fill="#fff" stroke="#000" stroke-width="1.4" stroke-linejoin="round"/></svg>',
  });

  inner.append(copy, win, pointer);
  ctx.layer.append(root);
  const blurInner = motionBlur(ctx.defs);

  // Measured once, with the window in place and the whip undone: the button
  // it opens from, and the name of the download that's clicked.
  let button: { x: number; y: number } | null = null;
  let target: { x: number; y: number } | null = null;
  const measure = (t: number) => {
    const shift = 1920 * whip(t);
    win.style.transform = "none";
    const b = where(openApp, ctx.camera);
    button = { x: b.cx + shift, y: b.cy };
    const name = where(rowEls[chosen].el.querySelector("b")!, ctx.camera);
    target = { x: name.x + shift + 64, y: name.cy + 4 };
  };

  /** The window's opening, from the button, and a slow push in while it's held. */
  const openness = (t: number) => ease.outExpo(seg(t, cue.open + 0.04, cue.open + 0.75));

  /** Where the pointer is, in the scene's own coordinates. */
  const pointerAt = (t: number) => {
    const start = { x: 1130, y: 1010 };
    const end = { x: button!.x - 6, y: button!.y - 8 };
    const a = ease.inOutCubic(seg(t, cue.open - 1.05, cue.open - 0.08));
    const [x, y] = cubic([start.x, start.y], [start.x + 60, start.y - 220], [end.x - 160, end.y + 120], [end.x, end.y], a);
    const b = ease.inOutCubic(seg(t, cue.select - 0.85, cue.select - 0.08));
    const [px, py] = cubic([x, y], [x - 120, y + 60], [target!.x + 260, target!.y - 40], [target!.x, target!.y], b);
    return { x: px, y: py };
  };

  const update = (t: number) => {
    if (!button) measure(t);
    const w = whip(t);
    const wv = (whip(t + 1 / 120) - whip(t - 1 / 120)) * 60;
    put(inner, { x: -1920 * w });
    blurInner(inner, wv * 1920 * 0.018);

    // The window zooms open from Open App, then the camera leans in a little.
    const s = Math.max(0.04, openness(t));
    const k = 1 + 0.025 * ease.inOutSine(seg(t, cue.open + 0.7, cue.whip));
    const o = { x: button!.x - frame.x, y: button!.y - frame.y };
    const c = { x: frame.w / 2, y: frame.h / 2 };
    const tx = c.x + k * (o.x - c.x) - k * s * o.x;
    const ty = c.y + k * (o.y - c.y) - k * s * o.y;
    win.style.transform = `translate3d(${tx.toFixed(2)}px, ${ty.toFixed(2)}px, 0) scale(${(k * s).toFixed(4)})`;
    win.style.opacity = seg(t, cue.open + 0.04, cue.open + 0.14).toFixed(3);
    win.style.filter = s < 0.98 ? `blur(${((1 - s) * 10).toFixed(2)}px)` : "none";

    // Its contents come with it, settling top to bottom as it lands.
    const settle = (el: HTMLElement, at: number, dy = 12) => {
      const p = softOut(seg(t, at, at + 0.5));
      put(el, { y: dy * (1 - p), o: 0.35 + 0.65 * seg(t, at, at + 0.3) });
    };
    [...side.children].forEach((el, i) => settle(el as HTMLElement, cue.open + 0.15 + i * 0.03, 8));
    settle(bar, cue.open + 0.15, 6);
    rowEls.forEach(({ el, fill, detail: text, row }, i) => {
      settle(el, cue.open + 0.18 + i * 0.03);
      if (row.total !== undefined) {
        const done = lerp(row.from!, row.to!, seg(t, cue.open, cue.whip));
        fill.style.width = `${(done * 100).toFixed(2)}%`;
        text.textContent = `Downloading · ${(row.total * done).toFixed(2)} GB of ${row.total} GB · ${row.left}`;
      } else {
        fill.style.width = "100%";
      }
      el.classList.toggle("is-selected", i === chosen && t >= cue.select + 0.02);
    });

    // The inspector: nothing selected, then what's inside Tears of Steel.
    const picked = seg(t, cue.select + 0.02, cue.select + 0.16);
    put(empty, { o: seg(t, cue.open + 0.3, cue.open + 0.6) * (1 - picked) });
    const shown = softOut(seg(t, cue.select + 0.06, cue.select + 0.6));
    put(detail, { y: 14 * (1 - shown), o: seg(t, cue.select + 0.06, cue.select + 0.3) });
    fileEls.forEach((el, i) => settle(el, cue.select + 0.2 + i * 0.03, 10));

    // The pointer: to Open App, a click, then to Tears of Steel and a click.
    const at = pointerAt(t);
    const press = 1 - 0.14 * Math.sin(Math.PI * seg(t, cue.open - 0.03, cue.open + 0.1)) - 0.14 * Math.sin(Math.PI * seg(t, cue.select - 0.03, cue.select + 0.1));
    put(pointer, { x: at.x, y: at.y, s: press, o: seg(t, cue.open - 1.05, cue.open - 0.9) * (1 - seg(t, cue.select + 0.45, cue.select + 0.75)) });

    // The words.
    rise([label], t, cue.open + 0.45, { length: 0.7 });
    rise(titleWords, t, cue.open + 0.55, { stagger: 0.06, length: 0.8 });
  };

  /** The orb in the inspector, as the app shows a download that's seeding. */
  const orb = (t: number): Place | null => {
    if (t < cue.select || t > cue.whip + 0.5) return null;
    const box = where(orbSlot, ctx.camera);
    const pop = spring(t, cue.select + 0.08, 2.6, 0.6);
    return { x: box.cx, y: box.cy, d: box.w * pop, opacity: seg(t, cue.select + 0.08, cue.select + 0.2) };
  };

  const scene: Scene = {
    from: cue.open - 1.1,
    to: cue.whip + 0.55,
    root,
    update,
  };
  return { scene, orb };
}
