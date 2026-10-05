// The website's own orb renderer, the same shader as the app's OrbView, driven
// frame by frame from the film's timeline instead of a clock.

import { OrbRenderer } from "../../../website/src/scripts/orb/renderer";
import { linear, palettes, type Palette } from "../../../website/src/scripts/orb/palette";
import type { Appearance } from "../../../website/src/scripts/orb/motion";
import { ease, keys, seg } from "./time";

// Screenshots read the canvas after drawing, so keep what was drawn.
const getContext = HTMLCanvasElement.prototype.getContext;
HTMLCanvasElement.prototype.getContext = function (this: HTMLCanvasElement, type: string, options?: object) {
  return (getContext as Function).call(this, type, type === "webgl2" ? { ...options, preserveDrawingBuffer: true } : options);
} as typeof getContext;

export type PaletteName = keyof typeof palettes;
const linearPalettes = Object.fromEntries(Object.entries(palettes).map(([k, v]) => [k, linear(v as Palette)])) as Record<PaletteName, Palette>;

export interface Look {
  level: number;
  energy: number;
  saturation: number;
  bloom: number;
  /** Palette changes: when each starts, and how long it takes. */
  palette: [number, PaletteName, number][];
  /** How fast the light flows and the globe turns. */
  flow: (t: number) => number;
  turn: (t: number) => number;
}

/** The palette at time t, blended between changes in linear light, as the app does. */
export function paletteAt(t: number, track: [number, PaletteName, number][]): Palette {
  let current = linearPalettes[track[0][1]];
  for (let i = 1; i < track.length; i++) {
    const [start, name, length] = track[i];
    if (t < start) break;
    const k = ease.inOutSine(seg(t, start, start + length));
    const next = linearPalettes[name];
    current = current.map((c, j) => c.map((v, n) => v + (next[j][n] - v) * k)) as Palette;
  }
  return current;
}

/** Integrates a speed over time once, so any frame can look up how far the flow and globe have gone. */
export function integrate(speed: (t: number) => number, until = 60, step = 1 / 240) {
  const table = new Float32Array(Math.ceil(until / step) + 2);
  let sum = 0;
  for (let i = 1; i < table.length; i++) {
    sum += speed((i - 0.5) * step) * step;
    table[i] = sum;
  }
  return (t: number) => {
    const x = Math.max(0, t / step);
    const i = Math.min(table.length - 2, Math.floor(x));
    return table[i] + (table[i + 1] - table[i]) * (x - i);
  };
}

export class VideoOrb {
  readonly canvas: HTMLCanvasElement;
  private renderer: OrbRenderer;
  private pad: number;

  constructor(parent: HTMLElement, className: string, pad = 0.3) {
    this.canvas = document.createElement("canvas");
    this.canvas.className = `orb ${className}`;
    parent.append(this.canvas);
    this.pad = pad;
    this.renderer = new OrbRenderer(this.canvas, pad);
  }

  get ready() {
    return this.renderer.ready;
  }

  /**
   * Puts the orb's centre at x, y, `d` across, and draws it. Bigger than
   * `largest`, it's drawn at that size and scaled up, as it's only that big
   * out of focus. `mask` is a CSS mask-image in the canvas's own pixels.
   */
  draw(x: number, y: number, d: number, appearance: Appearance | null, { opacity = 1, sx = 1, sy = 1, rotate = 0, stretch = 1, angle = 0, blur = 0, brightness = 1, mask = "" } = {}) {
    if (!appearance || opacity <= 0.001 || d < 1) {
      this.canvas.style.visibility = "hidden";
      return;
    }
    const largest = 2000;
    const up = Math.max(1, d / largest);
    const span = (d / up) * (1 + 2 * this.pad);
    const style = this.canvas.style;
    style.visibility = "visible";
    style.width = `${span.toFixed(2)}px`;
    style.height = `${span.toFixed(2)}px`;
    // A stretch along the direction of travel, then the usual squash.
    const along = stretch !== 1 ? `rotate(${angle.toFixed(2)}deg) scale(${stretch.toFixed(4)}, ${(1 / Math.sqrt(stretch)).toFixed(4)}) rotate(${(-angle).toFixed(2)}deg) ` : "";
    style.transform = `translate3d(${(x - span / 2).toFixed(2)}px, ${(y - span / 2).toFixed(2)}px, 0) ${along}scale(${(sx * up).toFixed(4)}, ${(sy * up).toFixed(4)}) rotate(${rotate.toFixed(2)}deg)`;
    const filters = [brightness !== 1 ? `brightness(${brightness.toFixed(3)})` : "", blur > 0.3 ? `blur(${(blur / up).toFixed(2)}px)` : ""].filter(Boolean);
    style.filter = filters.length ? filters.join(" ") : "none";
    style.maskImage = mask || "none";
    style.opacity = opacity.toFixed(4);
    this.renderer.resize();
    this.renderer.draw(appearance);
  }
}

/** A look described by tracks, turned into what the renderer needs at time t. */
export function appearance(t: number, tracks: {
  level: (t: number) => number;
  energy: (t: number) => number;
  saturation: (t: number) => number;
  bloom: (t: number) => number;
  palette: [number, PaletteName, number][];
  phase: (t: number) => number;
  spin: (t: number) => number;
}): Appearance {
  return {
    level: Math.max(0.05, Math.min(1, tracks.level(t))),
    energy: tracks.energy(t),
    saturation: tracks.saturation(t),
    bloom: Math.min(1, tracks.bloom(t)),
    palette: paletteAt(t, tracks.palette),
    phase: tracks.phase(t),
    spin: tracks.spin(t),
  };
}

export { keys };
