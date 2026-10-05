// 8. The site's own headline, with the orb dropping in as the o of "torrent",
// then where to get it.

import { cue, duration } from "../cues";
import { h, put, rise, where, words } from "../lib/dom";
import { icon } from "../lib/icons";
import { fx } from "../lib/stage";
import { ease, hex, lerp, seg, softOut, spring } from "../lib/time";
import type { Context, Place, Scene } from "./types";

export function finale(ctx: Context) {
  const root = h("div", { class: "scene" });
  const block = h("div", { class: "s8-block" });

  const label = h("p", { class: "label label-dot", style: "--dot: #3885ff" }, h("span", {}, "OrbTorrent"));
  const labelWrap = h("div", { class: "word s8-label" }, label);

  const title = h("h1", { class: "headline s8-title" });
  const lineA = h("span", { class: "line" });
  const lineB = h("span", { class: "line tone" });
  title.append(lineA, lineB);
  // "The t·o·rrent app", with the o kept as a gap the orb fills.
  const the = words(lineA, "The");
  lineA.append(" ");
  const o = h("span", { class: "s8-o" }, "o");
  const torrent = h("span", { class: "word" }, h("span", { class: "word-in" }, "t", o, "rrent"));
  lineA.append(torrent, " ");
  const app = words(lineA, "app");
  const made = words(lineB, "made for your Mac.");
  const titleWords = [...the, torrent.firstElementChild as HTMLElement, ...app, ...made];

  // A copy of the words for the light that sweeps across them.
  const shine = title.cloneNode(true) as HTMLElement;
  shine.classList.add("s8-shine");
  shine.setAttribute("aria-hidden", "true");
  const shineWords = [...shine.querySelectorAll<HTMLElement>(".word-in")];

  const button = h("span", { class: "s8-button" }, "orbtorrent.com", h("i", { html: icon("arrowUpRight", 26, 2.4) }));
  const note = h("span", { class: "s8-note" }, "Free for macOS 26 or later · Apple silicon and Intel");
  const cta = h("div", { class: "s8-cta" }, button, note);

  const titleWrap = h("div", { class: "s8-title-wrap" }, title, shine);
  block.append(labelWrap, titleWrap, cta);
  root.append(block);
  ctx.layer.append(root);

  let measured = false;
  const lift = (t: number) => softOut(seg(t, cue.lockup, cue.lockup + 0.9));

  const update = (t: number) => {
    put(block, { y: -64 * lift(t) });
    rise(titleWords, t, cue.finale, { stagger: 0.055, length: 0.75 });
    rise(shineWords, t, cue.finale, { stagger: 0.055, length: 0.75 });
    rise([label], t, cue.lockup + 0.12, { length: 0.7 });
    const b = spring(t, cue.lockup + 0.2, 2.2, 0.7);
    put(button, { y: 30 * (1 - b), s: 0.92 + 0.08 * b, o: seg(t, cue.lockup + 0.2, cue.lockup + 0.4) });
    put(note, { y: 20 * (1 - softOut(seg(t, cue.lockup + 0.32, cue.lockup + 1))), o: seg(t, cue.lockup + 0.32, cue.lockup + 0.6) });

    // Light sweeps across the words.
    const s = ease.inOutSine(seg(t, cue.shine, cue.shine + 1.1));
    shine.style.setProperty("--sweep", `${lerp(-30, 130, s).toFixed(2)}%`);
    shine.style.opacity = s > 0 && s < 1 ? "1" : "0";

    // The sweep's gradient spans the whole headline, so each word shows its part of it.
    if (!measured && t >= cue.shine - 0.5) {
      const box = where(title, ctx.camera);
      shineWords.forEach((word) => {
        const at = where(word, ctx.camera);
        word.style.backgroundSize = `${box.w}px ${box.h}px`;
        word.style.backgroundPosition = `${box.x - at.x}px ${box.y - at.y}px`;
      });
      measured = true;
    }
  };

  const hero = (t: number): Place => {
    const slot = where(o, ctx.camera);
    const p = seg(t, cue.finale, cue.seat);
    const q = ease.inOutCubic(p);
    const fromD = 430;
    const toD = parseFloat(getComputedStyle(title).fontSize) * 0.54;
    // A hop up, then down into its place in the word.
    const x = lerp(960, slot.cx, q);
    const y = lerp(520, slot.cy + slot.h * 0.06, q) - Math.sin(Math.PI * p) * 120;
    const d = Math.exp(lerp(Math.log(fromD), Math.log(toD), ease.inOutQuad(p)));
    const settle = t - cue.seat;
    const squash = settle > 0 ? 0.28 * Math.exp(-settle / 0.12) * Math.cos(settle * 2 * Math.PI * 5) : 0;
    return { x, y, d, sx: 1 + squash, sy: 1 - squash };
  };

  const scene: Scene = {
    from: cue.finale - 0.05,
    to: duration + 0.1,
    root,
    update,
    effects(t) {
      const p = seg(t, cue.seat, cue.seat + 0.7);
      if (p > 0 && p < 1) {
        const at = hero(t);
        fx.ring(ctx.back, at.x, at.y, at.d / 2 + 140 * ease.outExpo(p), 2.5 * (1 - p), hex("#9cc4ff"), 0.9 * (1 - p), 12);
      }
      const f = seg(t, cue.seat, cue.seat + 0.6);
      if (f > 0 && f < 1) {
        ctx.front.fillStyle = `rgba(210, 228, 255, ${(0.32 * (1 - ease.outCubic(f))).toFixed(3)})`;
        ctx.front.fillRect(0, 0, 1920, 1080);
      }
    },
    stage(t, add) {
      const p = seg(t, cue.seat, cue.seat + 1.4);
      if (p > 0 && p < 1) {
        const at = hero(cue.seat);
        add.ripples.push({ x: at.x, y: at.y, r: 40 + 1600 * ease.outExpo(seg(t, cue.seat, cue.seat + 1.1)), strength: 0.8 * (1 - p), width: 90 });
      }
    },
  };
  return { scene, hero };
}
