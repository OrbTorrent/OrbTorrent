// 7. Done: the orb turns green and grows, sharing pieces back out. Then what
// OrbTorrent is, one word a beat.

import { cue } from "../cues";
import { chars, h, motionBlur, put, rise, sink, words } from "../lib/dom";
import { fx } from "../lib/stage";
import { cubic, ease, hex, keys, lerp, random, seg, softOut, type RGB } from "../lib/time";
import type { Context, Place, Scene } from "./types";
import { doneNode } from "./s6-extensions";

export const big = { x: 960, y: 440, d: 380 };
export const side = { x: 500, y: 540, d: 330 };
const facts = ["Free.", "Open source.", "No ads.", "No account.", "Native."];

export function factsScene(ctx: Context) {
  const root = h("div", { class: "scene" });
  const done = h("h2", { class: "headline s7-done" });
  const doneA = words(done, "Done,");
  const doneTone = h("span", { class: "tone" });
  done.append(" ", doneTone);
  const doneB = words(doneTone, "and shared back.");

  const factEls = facts.map((text, i) => {
    const counter = h("p", { class: "label label-dot", style: "--dot: #33d98c" }, h("span", {}, `0${i + 1} / 05`));
    const word = h("p", { class: "s7-fact" });
    const letters = chars(word, text, "s7-char");
    const el = h("div", { class: "s7-fact-wrap" }, counter, word);
    return { el, word, letters, counter };
  });
  root.append(done, ...factEls.map((f) => f.el));
  ctx.layer.append(root);
  const blurs = factEls.map(() => motionBlur(ctx.defs));

  const rand = random(31);
  const sharing = Array.from({ length: 160 }, () => ({
    a: rand() * Math.PI * 2,
    start: cue.finished + 0.12 + rand() * 0.9,
    speed: 500 + rand() * 900,
    size: 2 + rand() * 3,
    colour: hex(["#33d98c", "#7af0c0", "#ffffff", "#5ad1ff"][Math.floor(rand() * 4)]) as RGB,
  }));

  const update = (t: number) => {
    rise(doneA, t, cue.finished + 0.1, { stagger: 0.06, length: 0.75 });
    rise(doneB, t, cue.finished + 0.25, { stagger: 0.06, length: 0.75 });
    sink([...doneA, ...doneB], t, cue.facts[0] - 0.55, { stagger: 0.02, length: 0.28 });

    factEls.forEach((f, i) => {
      const at = cue.facts[i];
      const next = i < facts.length - 1 ? cue.facts[i + 1] : cue.finale - 0.45;
      const on = t >= at - 0.02 && t < next;
      f.el.style.display = on ? "block" : "none";
      if (!on) return;
      const s = t - at;
      const leave = seg(t, next - 0.1, next);
      rise([f.counter], t, at, { length: 0.3 });
      // Each word arrives its own way.
      if (i === 0) {
        const p = ease.outExpo(seg(s, 0, 0.22));
        put(f.word, { s: 1.35 - 0.35 * p, o: seg(s, 0, 0.06) * (1 - leave), blur: (1 - p) * 18 + leave * 14 });
      } else if (i === 1) {
        put(f.word, { o: 1 - leave, blur: leave * 14 });
        f.letters.forEach((c, k) => {
          const p = softOut(seg(s, k * 0.016, k * 0.016 + 0.3));
          put(c, { y: (1 - p) * 120, o: seg(s, k * 0.016, k * 0.016 + 0.1), r: (1 - p) * 12 });
        });
      } else if (i === 2) {
        const p = ease.outExpo(seg(s, 0, 0.28));
        const v = (ease.outExpo(seg(s + 1 / 60, 0, 0.28)) - p) * 60;
        const x = 700 * (1 - p) - 900 * ease.inCubic(leave);
        put(f.word, { x, o: 1 - leave * 0.5 });
        blurs[i](f.word, v * 700 * 0.02 + leave * 30, 0);
      } else if (i === 3) {
        const p = ease.outExpo(seg(s, 0, 0.26));
        f.word.style.clipPath = `inset(${((1 - p) * 50).toFixed(2)}% 0 ${((1 - p) * 50).toFixed(2)}% 0)`;
        put(f.word, { sy: 1 + 0.25 * (1 - p), sx: 1, o: 1 - leave, blur: leave * 14 });
      } else {
        put(f.word, { o: 1 - leave, blur: leave * 16, s: 1 + 0.06 * leave });
        const n = f.letters.length;
        f.letters.forEach((c, k) => {
          const p = ease.outExpo(seg(s, 0, 0.32));
          put(c, { x: (1 - p) * (k - (n - 1) / 2) * 80, o: seg(s, Math.abs(k - (n - 1) / 2) * 0.02, 0.12 + Math.abs(k - (n - 1) / 2) * 0.02), blur: (1 - p) * 10 });
        });
      }
    });
  };

  const hero = (t: number): Place => {
    // Out of the Done node, up and big.
    const p = ease.outExpo(seg(t, cue.finished - 0.05, cue.finished + 0.6));
    const [gx, gy] = cubic([doneNode.x, doneNode.y], [doneNode.x - 60, doneNode.y - 360], [big.x + 300, big.y + 40], [big.x, big.y], p);
    const gd = Math.exp(lerp(Math.log(54), Math.log(big.d), p));
    // To the side for the words.
    const q = ease.inOutCubic(seg(t, cue.facts[0] - 0.5, cue.facts[0] - 0.1));
    let x = lerp(gx, side.x, q);
    let y = lerp(gy, side.y, q);
    let d = lerp(gd, side.d, q);
    const beat = cue.facts.reduce((sum, at) => sum + Math.exp(-Math.max(0, t - at) / 0.12) * (t >= at ? 1 : 0), 0);
    d *= 1 + 0.07 * Math.min(1, beat);
    // Then the riser: to the middle, growing, ready for the name.
    const r = ease.inOutCubic(seg(t, cue.finale - 0.5, cue.finale));
    x = lerp(x, 960, r);
    y = lerp(y, 520, r);
    d = lerp(d, keys(t, [[cue.finale - 0.5, side.d], [cue.finale, 430]]), r);
    return { x, y: y + Math.sin(t * 2) * 4, d };
  };

  const scene: Scene = {
    from: cue.finished - 0.1,
    to: cue.finale + 0.05,
    root,
    update,
    effects(t) {
      // Pieces shared back out, to everyone.
      const c = ctx.back;
      const o = hero(t);
      for (const s of sharing) {
        const age = t - s.start;
        if (age < 0 || age > 1.1) continue;
        const k = ease.inQuad(age / 1.1);
        const r = o.d / 2 + s.speed * k * 1.2;
        const x = o.x + Math.cos(s.a) * r;
        const y = o.y + Math.sin(s.a) * r * 0.9;
        const v = s.speed * 0.02 * (0.3 + k);
        fx.piece(c, x, y, Math.cos(s.a) * v, Math.sin(s.a) * v * 0.9, s.size, s.colour, Math.min(1, age / 0.1) * (1 - age / 1.1));
      }
      // A ring on every beat of the words.
      for (const at of cue.facts) {
        const p = seg(t, at, at + 0.5);
        if (p > 0 && p < 1) fx.ring(c, o.x, o.y, o.d / 2 + 260 * ease.outExpo(p), 2.5 * (1 - p), hex("#7af0c0"), 0.7 * (1 - p), 14);
      }
      // The riser: pieces pulled in from everywhere.
      const rise = seg(t, cue.rise + 0.2, cue.finale);
      if (rise > 0) {
        const rand = random(77);
        for (let i = 0; i < 90; i++) {
          const a = rand() * Math.PI * 2;
          const delay = rand() * 0.55;
          const p = seg(t, cue.rise + 0.2 + delay, cue.rise + 0.2 + delay + 0.5);
          if (p <= 0 || p >= 1) continue;
          const r = lerp(1200, o.d / 2, ease.inCubic(p));
          const x = o.x + Math.cos(a + p * 0.8) * r;
          const y = o.y + Math.sin(a + p * 0.8) * r * 0.8;
          fx.piece(c, x, y, -Math.cos(a) * 30 * p, -Math.sin(a) * 30 * p, 2.5 + rand() * 2, hex(rand() < 0.5 ? "#8fb2ff" : "#ffffff"), Math.min(1, p * 4) * 0.9);
        }
      }
    },
  };
  return { scene, hero };
}
