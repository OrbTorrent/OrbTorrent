// 1. The orb comes to light, as in an eclipse: a crescent on its rim grows
// as the intro swells, until the whole orb lights up. Then its name and what
// it is, and it's off to the menu bar.

import { cue } from "../cues";
import { chars, h, put, rise, sink, words } from "../lib/dom";
import { fx } from "../lib/stage";
import { light as paper, tone } from "../theme";
import { ease, hit, keys, lerp, pulse, quad, rgba, seg } from "../lib/time";
import type { Context, Place, Scene } from "./types";

export const centre = { x: 960, y: 420 };
const D = 320;
/** Where the light comes from: the top left, as on the orb's glass. */
const light = { x: -0.543, y: -0.84 };

export function ignition(ctx: Context, slot: () => { x: number; y: number }) {
  const root = h("div", { class: "scene" });
  const name = h("div", { class: "s1-name" });
  const letters = chars(name, "OrbTorrent");
  const tagline = h("p", { class: "s1-tagline" });
  const tagWords = words(tagline, "The torrent app");
  tagline.append(" ");
  tagWords.push(...words(tagline, "made for your Mac.", "tone"));
  root.append(name, tagline);
  ctx.layer.append(root);

  /** How far the shadow has moved off the orb, in diameters. */
  const shadow = (t: number) =>
    lerp(
      keys(t, [[0.3, 0.03], [1.3, 0.07, ease.outQuad], [cue.full - 0.04, 0.34, ease.inOutSine]]),
      1.6,
      ease.outCubic(seg(t, cue.full - 0.04, cue.full + 0.4)),
    );
  /** How far it's lit, once it lights up, 0 to 1. */
  const lit = (t: number) => seg(t, cue.full - 0.04, cue.full + 0.4);
  const eclipse = (t: number): Place => {
    const punch = 1 + 0.06 * pulse(t, cue.full - 0.03, 0.4);
    const d = D * (0.95 + 0.05 * ease.inOutSine(seg(t, 0, cue.full))) * punch;
    // The shadow: a disc a little bigger than the orb, moved away from the light.
    const off = shadow(t) * d;
    const span = d * 1.6;
    const cx = span / 2 - light.x * off;
    const cy = span / 2 - light.y * off;
    const r = 0.53 * d;
    const soft = d * (0.02 + 0.12 * seg(shadow(t), 0.05, 0.4) + 0.6 * ease.outQuad(lit(t)));
    return {
      x: centre.x,
      y: centre.y,
      d,
      mask: `radial-gradient(circle at ${cx.toFixed(1)}px ${cy.toFixed(1)}px, transparent ${r.toFixed(1)}px, #000 ${(r + soft).toFixed(1)}px)`,
      opacity: ease.inOutSine(seg(t, 0.2, 0.7)),
      brightness: 1.1 + 0.25 * hit(t, cue.full, 0.35) * (t >= cue.full ? 1 : 0) - 0.1 * lit(t),
      spot: seg(t, cue.full - 0.1, cue.full + 0.4),
    };
  };

  /** Where the hero orb is in this scene. */
  const hero = (t: number): Place => {
    if (t < cue.launch) {
      const at = eclipse(t);
      const float = Math.sin((t - cue.full) * 2.1) * 4 * seg(t, cue.full + 0.4, cue.full + 1);
      return { ...at, y: at.y + float };
    }
    // A crouch, then off along an arc, faster and faster, into the menu bar,
    // stretched along the way it's going.
    const at = flight(t);
    const ahead = flight(t + 0.004);
    const behind = flight(t - 0.004);
    const vx = (ahead.x - behind.x) / 0.008;
    const vy = (ahead.y - behind.y) / 0.008;
    const speed = Math.hypot(vx, vy);
    return { ...at, stretch: 1 + Math.min(0.5, speed / 7000), angle: (Math.atan2(vy, vx) * 180) / Math.PI };
  };
  function flight(t: number) {
    const crouch = ease.outCubic(seg(t, cue.launch, cue.launch + 0.18)) * (1 - ease.inCubic(seg(t, cue.launch + 0.18, cue.launch + 0.36)));
    const p = seg(t, cue.launch + 0.15, cue.land);
    const u = ease.inCubic(p) * 0.82 + ease.inOutCubic(p) * 0.18;
    const end = slot();
    const float = Math.sin((cue.launch - cue.full) * 2.1) * 4;
    const [x, y] = quad([centre.x, centre.y + float + 14 * crouch], [1240, 100], [end.x, end.y], u);
    const d = Math.exp(lerp(Math.log(D * (1 + 0.08 * crouch)), Math.log(28), ease.inOutCubic(p)));
    return { x, y, d };
  }

  const update = (t: number) => {
    // The name, gathering in from wide tracking, then swept up after the orb.
    const n = letters.length;
    letters.forEach((letter, i) => {
      const fromMiddle = Math.abs(i - (n - 1) / 2) / ((n - 1) / 2);
      const p = ease.outExpo(seg(t, cue.name + fromMiddle * 0.1, cue.name + 1.2));
      const spread = (1 - p) * (i - (n - 1) / 2) * 22;
      const leave = ease.inBack(seg(t, cue.launch + 0.08 + i * 0.022, cue.launch + 0.48 + i * 0.022), 2.2);
      put(letter, {
        x: spread + leave * 90,
        y: (1 - p) * 8 - leave * 150,
        o: Math.min(seg(t, cue.name + fromMiddle * 0.12, cue.name + 0.45 + fromMiddle * 0.12), 1 - leave),
        blur: (1 - p) * 12 + leave * 10,
        s: 1 - leave * 0.4,
      });
    });
    // What it is, rising word by word, and gone just before the orb leaves.
    rise(tagWords, t, cue.tagline, { stagger: 0.07, length: 0.8 });
    sink(tagWords, t, cue.launch - 0.2, { stagger: 0.025, length: 0.4 });
  };

  const effects = (t: number) => {
    const { x: cx, y: cy } = centre;
    if (t < cue.full + 0.6) {
      // The rest of the rim, just showing against the dark, as eyes adjust,
      // or faintly drawn on paper.
      const { d } = eclipse(t);
      const show = seg(t, 0.8, 2.6) * (1 - lit(t));
      if (show > 0.002) {
        const c = ctx.back;
        const rim = paper ? ([19, 19, 22] as const) : ([200, 220, 255] as const);
        const under = paper ? ([19, 19, 22] as const) : ([160, 190, 255] as const);
        const k = paper ? 0.5 : 1;
        const ring = c.createConicGradient(Math.atan2(light.y, light.x), cx, cy);
        ring.addColorStop(0, rgba([...rim], 0.5 * show * k));
        ring.addColorStop(0.3, rgba([...rim], 0.06 * show * (paper ? 1.5 : 1)));
        ring.addColorStop(0.62, rgba([...under], 0.16 * show * k));
        ring.addColorStop(0.7, rgba([...rim], 0.06 * show * (paper ? 1.5 : 1)));
        ring.addColorStop(1, rgba([...rim], 0.5 * show * k));
        c.save();
        c.strokeStyle = ring;
        c.lineWidth = 1.6;
        c.beginPath();
        c.arc(cx, cy, d / 2 - 1.5, 0, Math.PI * 2);
        c.stroke();
        c.restore();
      }
      // As it lights: a glint where the light first reaches round the rim.
      const g = hit(t, cue.full - 0.06, 0.32) * (t >= cue.full - 0.06 ? 1 : 0) + 0.35 * pulse(t, cue.full - 0.9, 0.9);
      if (g > 0.003) {
        const gx = cx + light.x * d * 0.47;
        const gy = cy + light.y * d * 0.47;
        const c = ctx.front;
        fx.glow(c, gx, gy, 150 * g + 30, [190, 220, 255], 0.75 * g);
        fx.glow(c, gx, gy, 16, [255, 255, 255], Math.min(1, 1.4 * g));
        const width = 340 * g;
        const streak = c.createLinearGradient(gx - width, 0, gx + width, 0);
        streak.addColorStop(0, rgba(tone([120, 180, 255]), 0));
        streak.addColorStop(0.5, rgba(tone([225, 240, 255]), (paper ? 0.45 : 0.7) * g));
        streak.addColorStop(1, rgba(tone([120, 180, 255]), 0));
        c.fillStyle = streak;
        c.fillRect(gx - width, gy - 1, width * 2, 2);
      }
    }
    // A soft flash of light as it comes to life.
    const flash = 0.18 * hit(t, cue.full, 0.22) * (t >= cue.full ? 1 : 0);
    if (flash > 0.002) fx.glow(ctx.front, cx, cy, 700, [150, 195, 255], flash);
    // The launch: a trail of light behind the orb.
    const from = cue.launch + 0.15;
    if (t > from && t < cue.land + 0.15) {
      const c = ctx.back;
      c.save();
      c.lineCap = "round";
      for (let k = 18; k >= 1; k--) {
        const a = hero(Math.max(from, Math.min(cue.land, t - k * 0.011)));
        const b = hero(Math.max(from, Math.min(cue.land, t - (k - 1) * 0.011)));
        const fade = (1 - k / 19) * (1 - seg(t, cue.land, cue.land + 0.15));
        c.strokeStyle = rgba(tone([120, 190, 255]), (paper ? 0.4 : 0.55) * fade);
        c.lineWidth = Math.max(1, b.d * 0.42 * (1 - k / 19));
        c.shadowColor = paper ? "rgba(56,133,255,0.4)" : "rgba(80,150,255,0.8)";
        c.shadowBlur = 16;
        c.beginPath();
        c.moveTo(a.x, a.y);
        c.lineTo(b.x, b.y);
        c.stroke();
      }
      c.restore();
    }
  };

  const scene: Scene = {
    from: 0,
    to: cue.land - 0.2,
    root,
    update,
    effects,
    stage(t, add) {
      const p = seg(t, cue.full, cue.full + 1.6);
      if (p > 0 && p < 1) add.ripples.push({ x: centre.x, y: centre.y, r: D / 2 + 1500 * ease.outExpo(seg(t, cue.full, cue.full + 1.2)), strength: 0.8 * (1 - p), width: 80 });
    },
  };
  return { scene, hero };
}
