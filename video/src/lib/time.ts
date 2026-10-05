// Timing: easing curves, springs, keyframes and a seeded random, all pure
// functions of time, so any frame can be drawn on its own.

export const clamp = (x: number, a = 0, b = 1) => Math.min(b, Math.max(a, x));
export const lerp = (a: number, b: number, t: number) => a + (b - a) * t;
/** How far t is from a to b, from 0 to 1. */
export const seg = (t: number, a: number, b: number) => clamp((t - a) / (b - a));
/** Rises from 0 to 1 over a→b, holds, then falls back over c→d. */
export const window4 = (t: number, a: number, b: number, c: number, d: number, e: Ease = ease.inOutCubic) =>
  Math.min(e(seg(t, a, b)), 1 - e(seg(t, c, d)));

export type Ease = (t: number) => number;

export const ease = {
  linear: (t: number) => t,
  inQuad: (t: number) => t * t,
  outQuad: (t: number) => 1 - (1 - t) * (1 - t),
  inOutQuad: (t: number) => (t < 0.5 ? 2 * t * t : 1 - (-2 * t + 2) ** 2 / 2),
  inCubic: (t: number) => t * t * t,
  outCubic: (t: number) => 1 - (1 - t) ** 3,
  inOutCubic: (t: number) => (t < 0.5 ? 4 * t * t * t : 1 - (-2 * t + 2) ** 3 / 2),
  inQuart: (t: number) => t ** 4,
  outQuart: (t: number) => 1 - (1 - t) ** 4,
  inOutQuart: (t: number) => (t < 0.5 ? 8 * t ** 4 : 1 - (-2 * t + 2) ** 4 / 2),
  outQuint: (t: number) => 1 - (1 - t) ** 5,
  inOutQuint: (t: number) => (t < 0.5 ? 16 * t ** 5 : 1 - (-2 * t + 2) ** 5 / 2),
  inExpo: (t: number) => (t <= 0 ? 0 : 2 ** (10 * t - 10)),
  outExpo: (t: number) => (t >= 1 ? 1 : 1 - 2 ** (-10 * t)),
  inOutExpo: (t: number) =>
    t <= 0 ? 0 : t >= 1 ? 1 : t < 0.5 ? 2 ** (20 * t - 10) / 2 : (2 - 2 ** (-20 * t + 10)) / 2,
  inOutSine: (t: number) => -(Math.cos(Math.PI * t) - 1) / 2,
  outBack: (t: number, s = 1.70158) => 1 + (s + 1) * (t - 1) ** 3 + s * (t - 1) ** 2,
  inBack: (t: number, s = 1.70158) => (s + 1) * t ** 3 - s * t * t,
};

/** CSS's cubic-bezier(), solved for y at x. */
export function bezier(x1: number, y1: number, x2: number, y2: number): Ease {
  const cx = 3 * x1, bx = 3 * (x2 - x1) - cx, ax = 1 - cx - bx;
  const cy = 3 * y1, by = 3 * (y2 - y1) - cy, ay = 1 - cy - by;
  const x = (s: number) => ((ax * s + bx) * s + cx) * s;
  const dx = (s: number) => (3 * ax * s + 2 * bx) * s + cx;
  const y = (s: number) => ((ay * s + by) * s + cy) * s;
  return (t: number) => {
    if (t <= 0) return 0;
    if (t >= 1) return 1;
    let s = t;
    for (let i = 0; i < 8; i++) {
      const e = x(s) - t;
      const d = dx(s);
      if (Math.abs(e) < 1e-6 || Math.abs(d) < 1e-6) break;
      s -= e / d;
    }
    return y(clamp(s));
  };
}

/** The site's own soft ease-out. */
export const softOut = bezier(0.22, 1, 0.36, 1);

/**
 * A spring released at `start`, as a 0→1 step: `frequency` in hertz and
 * `damping` as a ratio, under 1 for an overshoot.
 */
export function spring(t: number, start: number, frequency = 2.2, damping = 0.55) {
  const s = t - start;
  if (s <= 0) return 0;
  const w0 = 2 * Math.PI * frequency;
  if (damping >= 1) return 1 - Math.exp(-w0 * s) * (1 + w0 * s);
  const wd = w0 * Math.sqrt(1 - damping * damping);
  return 1 - Math.exp(-damping * w0 * s) * (Math.cos(wd * s) + ((damping * w0) / wd) * Math.sin(wd * s));
}

/** Keyframes: [time, value, ease into this key]. Holds before the first and after the last. */
export function keys(t: number, frames: [number, number, Ease?][]) {
  if (t <= frames[0][0]) return frames[0][1];
  for (let i = 1; i < frames.length; i++) {
    const [t1, v1, e = ease.inOutCubic] = frames[i];
    if (t <= t1) {
      const [t0, v0] = frames[i - 1];
      return lerp(v0, v1, e(seg(t, t0, t1)));
    }
  }
  return frames[frames.length - 1][1];
}

/** A bump from 0 up to 1 and back over `length` seconds from `start`. */
export const pulse = (t: number, start: number, length: number) => {
  const s = (t - start) / length;
  return s <= 0 || s >= 1 ? 0 : Math.sin(Math.PI * s);
};

/** A sharp hit that decays: 1 at `start`, falling away. */
export const hit = (t: number, start: number, decay = 0.25) => (t < start ? 0 : Math.exp(-(t - start) / decay));

/** Mulberry32: a small seeded random, so every render is the same. */
export function random(seed: number) {
  let a = seed >>> 0;
  return () => {
    a = (a + 0x6d2b79f5) >>> 0;
    let r = Math.imul(a ^ (a >>> 15), 1 | a);
    r = (r + Math.imul(r ^ (r >>> 7), 61 | r)) ^ r;
    return ((r ^ (r >>> 14)) >>> 0) / 4294967296;
  };
}

/** A smooth value noise, for gentle drifting. */
export function drift(t: number, seed: number) {
  return (
    Math.sin(t * 0.73 + seed * 1.7) * 0.5 +
    Math.sin(t * 1.31 + seed * 3.1) * 0.3 +
    Math.sin(t * 2.17 + seed * 5.3) * 0.2
  );
}

export type RGB = [number, number, number];
export const hex = (h: string): RGB => {
  const n = parseInt(h.slice(1), 16);
  return [(n >> 16) & 255, (n >> 8) & 255, n & 255];
};
export const mixRGB = (a: RGB, b: RGB, t: number): RGB => [lerp(a[0], b[0], t), lerp(a[1], b[1], t), lerp(a[2], b[2], t)];
export const rgba = (c: RGB, a = 1) => `rgba(${c[0].toFixed(1)}, ${c[1].toFixed(1)}, ${c[2].toFixed(1)}, ${a.toFixed(4)})`;

/** A point on a cubic Bézier curve. */
export function cubic(p0: number[], p1: number[], p2: number[], p3: number[], t: number) {
  const u = 1 - t;
  return [0, 1].map((i) => u * u * u * p0[i] + 3 * u * u * t * p1[i] + 3 * u * t * t * p2[i] + t * t * t * p3[i]);
}
export function quad(p0: number[], p1: number[], p2: number[], t: number) {
  const u = 1 - t;
  return [0, 1].map((i) => u * u * p0[i] + 2 * u * t * p1[i] + t * t * p2[i]);
}
