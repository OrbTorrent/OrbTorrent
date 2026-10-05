// 3. A magnet link decodes itself, a pointer clicks it, and its characters
// pour into the orb, which starts to fill. "Click a magnet link. It's
// downloading."

import { cue } from "../cues";
import { chars, h, motionBlur, put, rise, sink, where, words } from "../lib/dom";
import { fx } from "../lib/stage";
import { cubic, ease, hex, keys, random, seg, softOut, spring } from "../lib/time";
import type { Context, Place, Scene } from "./types";
import { whip } from "./s2-menubar";

// Big Buck Bunny, the Blender Foundation's open film, with the docs' example tracker.
const link = "magnet:?xt=urn:btih:dd8255ecdc7ca55fb0bbf81323d87062db1f6d1c&dn=Big+Buck+Bunny&tr=udp%3A%2F%2Ftracker.example.org%3A1337";
const glyphs = "0123456789abcdef%:?&=+ABCDEFxyz";
export const orbHome = { x: 1420, y: 452, d: 330 };

export function magnet(ctx: Context) {
  const root = h("div", { class: "scene" });
  const inner = h("div", { class: "s3-inner" });
  root.append(inner);

  const label = h("p", { class: "label label-dot", style: "--dot: #3885ff" }, h("span", {}, "Magnet links and .torrent files"));
  const text = h("p", { class: "s3-link" });
  const letters = chars(text, link, "s3-char");
  const card = h(
    "div",
    { class: "s3-card glass" },
    h("div", { class: "s3-card-head" }, h("span", { class: "s3-dots" }, h("i"), h("i"), h("i")), h("span", {}, "Big Buck Bunny · Blender Foundation · 1080p")),
    text,
  );
  const pointer = h("div", {
    class: "pointer",
    html: '<svg width="40" height="56" viewBox="0 0 20 28"><path d="M2 1.5v21.2l5.2-5 3.3 7.8 3.6-1.5-3.3-7.6h7.1z" fill="#fff" stroke="#000" stroke-width="1.4" stroke-linejoin="round"/></svg>',
  });

  const title = h("h2", { class: "headline s3-title" });
  const lineA = h("span", { class: "line" });
  const lineB = h("span", { class: "line tone" });
  title.append(lineA, lineB);
  const wordsA = words(lineA, "Click a magnet link.");
  const wordsB = words(lineB, "It’s downloading.");
  const labelWrap = h("div", { class: "word s3-tag" }, label);

  const status = h("p", { class: "label label-dot s3-status", style: "--dot: #3885ff" }, h("span", {}, "Downloading"));
  const statusText = status.querySelector("span")!;
  const meterFill = h("span");
  const meter = h("span", { class: "meter" }, meterFill);
  const meterText = h("p", { class: "s3-meter-text" });
  const readout = h("div", { class: "s3-readout" }, status, meter, meterText);

  inner.append(labelWrap, card, title, readout, pointer);
  ctx.layer.append(root);
  const blurInner = motionBlur(ctx.defs);

  // Where each character starts, measured once laid out, for the pour.
  let homes: { x: number; y: number }[] | null = null;
  const rand = random(5);
  const arcs = letters.map(() => ({ lift: -120 - rand() * 220, delay: rand() * 0.16, spin: (rand() - 0.5) * 220 }));

  const pointerPath = (t: number) => {
    const p = ease.inOutCubic(seg(t, cue.click - 0.62, cue.click - 0.06));
    const [x, y] = cubic([1180, 1000], [1000, 860], [760, 560], [588, 452], p);
    return { x, y };
  };

  const update = (t: number) => {
    const w = whip(t);
    const wv = (whip(t + 1 / 120) - whip(t - 1 / 120)) * 60;
    put(inner, { x: 1920 * (1 - w) });
    blurInner(inner, wv * 1920 * 0.018);

    if (!homes && t >= cue.magnet - 0.3) {
      homes = letters.map((l) => {
        const b = where(l, ctx.camera);
        return { x: b.cx - 1920 * (1 - w), y: b.cy };
      });
    }

    rise([label], t, cue.magnet, { length: 0.7 });
    put(card, { y: 20 * (1 - softOut(seg(t, cue.magnet - 0.05, cue.magnet + 0.65))), o: seg(t, cue.magnet - 0.1, cue.magnet + 0.2) * (1 - seg(t, cue.absorb, cue.absorb + 0.3)) });
    card.classList.toggle("is-hover", t > cue.click - 0.1 && t < cue.click + 0.25);

    // Each character settles from a scramble, then pours into the orb.
    const frame = Math.floor(t * 60);
    letters.forEach((letter, i) => {
      const settle = cue.magnet + 0.04 + i * 0.0045;
      const shown = t > cue.magnet - 0.02 + i * 0.0022;
      letter.textContent = !shown ? " " : t < settle ? glyphs[(frame * 7 + i * 13) % glyphs.length] : link[i];
      letter.classList.toggle("is-scrambled", t < settle);
      const start = cue.click + 0.04 + arcs[i].delay + (i / letters.length) * 0.1;
      const p = seg(t, start, start + 0.34);
      letter.classList.toggle("is-flying", p > 0);
      if (p > 0 && homes) {
        const home = homes[i];
        const q = ease.inCubic(p);
        const [x, y] = cubic([home.x, home.y], [home.x + 160, home.y + arcs[i].lift], [orbHome.x - 260, orbHome.y - 120], [orbHome.x, orbHome.y], q);
        put(letter, { x: x - home.x, y: y - home.y, s: 1 - 0.7 * q, r: arcs[i].spin * q, o: 1 - seg(p, 0.75, 1) });
      } else {
        put(letter, {});
      }
    });

    // The pointer, gliding in to click.
    const ptr = pointerPath(t);
    const press = 1 - 0.14 * Math.sin(Math.PI * seg(t, cue.click - 0.03, cue.click + 0.1));
    put(pointer, { x: ptr.x, y: ptr.y, s: press, o: seg(t, cue.click - 0.62, cue.click - 0.48) * (1 - seg(t, cue.click + 0.25, cue.click + 0.45)) });

    // The words, then up into the space the card leaves.
    const up = softOut(seg(t, cue.absorb + 0.15, cue.absorb + 0.9));
    put(title, { y: -250 * up });
    rise(wordsA, t, cue.click - 0.04, { stagger: 0.06, length: 0.75 });
    rise(wordsB, t, cue.absorb, { stagger: 0.06, length: 0.75 });
    sink([...wordsA, ...wordsB], t, cue.toVpn - 0.3, { stagger: 0.02, length: 0.3 });
    put(labelWrap, { o: 1 - seg(t, cue.absorb, cue.absorb + 0.3) });

    // The orb's readout.
    const level = keys(t, [[cue.absorb, 0.0], [cue.absorb + 1.6, 0.42, ease.outCubic]]);
    statusText.textContent = `Downloading · ${Math.round(level * 100)}%`;
    meterFill.style.width = `${(level * 100).toFixed(2)}%`;
    meterText.textContent = `${(276.4 * level).toFixed(1)} MB of 276.4 MB · ↓ ${(2.2 + 0.3 * Math.abs(Math.sin(Math.floor(t * 5)))).toFixed(1)} MB/s`;
    const r = spring(t, cue.absorb + 0.15, 2.4, 0.8);
    put(readout, { y: 24 * (1 - r), o: seg(t, cue.absorb + 0.15, cue.absorb + 0.4) * (1 - seg(t, cue.toVpn - 0.2, cue.toVpn + 0.05)) });
  };

  const hero = (t: number): Place => {
    const w = whip(t);
    const take = Math.sin(Math.PI * seg(t, cue.absorb - 0.04, cue.absorb + 0.26));
    return { x: orbHome.x + 1920 * (1 - w), y: orbHome.y + Math.sin(t * 1.9) * 4, d: orbHome.d * (1 + 0.06 * take) };
  };

  const scene: Scene = {
    from: cue.whip - 0.15,
    to: cue.toVpn + 0.4,
    root,
    update,
    effects(t) {
      // A ripple where it's clicked, and sparks as the link pours in.
      const p = seg(t, cue.click, cue.click + 0.45);
      if (p > 0 && p < 1) {
        const at = pointerPath(cue.click);
        fx.ring(ctx.back, at.x + 4, at.y + 4, 8 + 60 * ease.outExpo(p), 2 * (1 - p), [180, 215, 255], 0.9 * (1 - p), 10);
      }
      const q = seg(t, cue.absorb - 0.05, cue.absorb + 0.6);
      if (q > 0 && q < 1) {
        fx.ring(ctx.back, orbHome.x, orbHome.y, orbHome.d / 2 + 220 * ease.outExpo(q), 3 * (1 - q), hex("#8fd0ff"), 0.8 * (1 - q), 18);
      }
    },
  };
  return { scene, hero };
}
