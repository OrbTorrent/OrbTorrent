// The night stage the orb is lit on, as on the website: dark, with a fine dot
// matrix and a glow rising from below in the orb's colour. Or the website's
// paper, in the light theme. Plus the Mac's wallpaper for scene 2, the effects
// canvases and the film grain.

import { glowAlpha, light, tone } from "../theme";
import { random, rgba, type RGB } from "./time";

export const W = 1920;
export const H = 1080;

export function canvas2d(parent: HTMLElement, className: string, scale: number) {
  const canvas = document.createElement("canvas");
  canvas.className = className;
  canvas.width = W * scale;
  canvas.height = H * scale;
  parent.append(canvas);
  const ctx = canvas.getContext("2d")!;
  ctx.setTransform(scale, 0, 0, scale, 0, 0);
  return { canvas, ctx, clear: () => { ctx.setTransform(1, 0, 0, 1, 0, 0); ctx.clearRect(0, 0, canvas.width, canvas.height); ctx.setTransform(scale, 0, 0, scale, 0, 0); } };
}

export interface Ripple { x: number; y: number; r: number; strength: number; width?: number; color?: RGB }

export interface StageState {
  tint: RGB;
  /** The glow from below, 0 to about 1. */
  glow: number;
  /** How much of the dot matrix shows. */
  dots: number;
  /** The dot matrix's sideways drift, in pixels, for camera moves. */
  shift: number;
  /** A soft light behind the orb. */
  spot?: { x: number; y: number; r: number; alpha: number };
  ripples: Ripple[];
  /** How much of the Mac's wallpaper shows, and where it's slid to. */
  wallpaper: number;
  wallpaperX: number;
  wallpaperBlur?: number;
  /** Overall brightness, for the fade from black. */
  light: number;
}

export class Stage {
  private ctx: CanvasRenderingContext2D;
  private wall: HTMLCanvasElement;
  private dotsX: number[] = [];
  private dotsY: number[] = [];
  private spacing = 20;

  constructor(parent: HTMLElement, scale: number) {
    this.ctx = canvas2d(parent, "layer stage", scale).ctx;
    this.wall = wallpaper();
    for (let y = this.spacing / 2; y < H; y += this.spacing) this.dotsY.push(y);
    for (let x = -this.spacing; x < W + this.spacing; x += this.spacing) this.dotsX.push(x);
  }

  draw(s: StageState) {
    const ctx = this.ctx;
    ctx.globalCompositeOperation = "source-over";
    ctx.globalAlpha = 1;
    ctx.fillStyle = light ? "#f6f5f1" : "#05070f";
    ctx.fillRect(0, 0, W, H);

    // radial-gradient(120% 90% at 50% 100%, #0c1636 0%, #070b1c 45%, night 80%),
    // or on paper, a little shade low down.
    ellipse(ctx, W / 2, H, W * 1.2, H * 0.9, light ? [[0, "#e9e6de"], [0.45, "#f0eee8"], [0.8, "#f6f5f1"]] : [[0, "#0c1636"], [0.45, "#070b1c"], [0.8, "#05070f"]]);
    // The tint, rising from below: radial-gradient(70% 55% at 50% 108%, tint 46%, transparent 70%).
    if (s.glow > 0.001) {
      ellipse(ctx, W / 2, H * 1.08, W * 0.7, H * 0.55, [[0, rgba(s.tint, (light ? 0.2 : 0.46) * s.glow)], [0.7, rgba(s.tint, 0)]]);
    }
    if (s.spot && s.spot.alpha > 0.001) {
      const alpha = s.spot.alpha * (light ? 0.45 : 1);
      const g = ctx.createRadialGradient(s.spot.x, s.spot.y, 0, s.spot.x, s.spot.y, s.spot.r);
      g.addColorStop(0, rgba(s.tint, alpha));
      g.addColorStop(0.45, rgba(s.tint, alpha * 0.35));
      g.addColorStop(1, rgba(s.tint, 0));
      ctx.fillStyle = g;
      ctx.fillRect(0, 0, W, H);
    }

    // The Mac's wallpaper, for scene 2.
    if (s.wallpaper > 0.001) {
      ctx.globalAlpha = s.wallpaper;
      if (s.wallpaperBlur && s.wallpaperBlur > 0.5) ctx.filter = `blur(${s.wallpaperBlur.toFixed(1)}px)`;
      // Drawn a little larger than the frame, so it can drift without showing an edge.
      ctx.drawImage(this.wall, s.wallpaperX - W * 0.04, -H * 0.04, W * 1.08, H * 1.08);
      ctx.filter = "none";
      ctx.globalAlpha = 1;
    }

    // The dot matrix, brightest low in the middle, lit up where ripples pass.
    if (s.dots > 0.001) {
      const offset = ((s.shift % this.spacing) + this.spacing) % this.spacing;
      const tint = s.tint;
      for (const y of this.dotsY) {
        for (const x0 of this.dotsX) {
          const x = x0 + offset;
          // mask-image: radial-gradient(75% 65% at 50% 85%, #000 10%, transparent 72%)
          const dx = (x - W / 2) / (W * 0.75), dy = (y - H * 0.85) / (H * 0.65);
          const d = Math.sqrt(dx * dx + dy * dy);
          let a = d < 0.1 ? 1 : d > 0.72 ? 0 : 1 - (d - 0.1) / 0.62;
          a *= (light ? 0.16 : 0.2) * 0.6 * s.dots;
          let lit = 0;
          for (const r of s.ripples) {
            const dist = Math.hypot(x - r.x, y - r.y);
            const k = (dist - r.r) / (r.width ?? 60);
            lit += r.strength * Math.exp(-k * k);
          }
          a = Math.min(1, a + 0.75 * lit);
          if (a < 0.01) continue;
          if (light) ctx.fillStyle = lit > 0.05 ? rgba(tint, a) : `rgba(19,19,22,${a.toFixed(3)})`;
          else ctx.fillStyle = lit > 0.05 ? rgba([255 - (255 - tint[0]) * 0.4, 255 - (255 - tint[1]) * 0.4, 255 - (255 - tint[2]) * 0.4], a) : `rgba(255,255,255,${a.toFixed(3)})`;
          const size = 1.7 + 1.6 * Math.min(1, lit);
          ctx.fillRect(x - size / 2, y - size / 2, size, size);
        }
      }
    }

    if (s.light < 0.999) {
      ctx.fillStyle = `rgba(0,0,0,${(1 - s.light).toFixed(4)})`;
      ctx.fillRect(0, 0, W, H);
    }
  }
}

function ellipse(ctx: CanvasRenderingContext2D, cx: number, cy: number, rx: number, ry: number, stops: [number, string][]) {
  ctx.save();
  ctx.translate(cx, cy);
  ctx.scale(rx / ry, 1);
  const g = ctx.createRadialGradient(0, 0, 0, 0, 0, ry);
  for (const [at, color] of stops) g.addColorStop(at, color);
  ctx.fillStyle = g;
  ctx.fillRect(-cx * (ry / rx) - 10, -cy - 10, (W * ry) / rx + 20, H + 20);
  ctx.restore();
}

/** A soft Mac wallpaper in the orb's colours, like the press shots', or a pale one in the light theme. */
function wallpaper() {
  const c = document.createElement("canvas");
  c.width = W;
  c.height = H;
  const ctx = c.getContext("2d")!;
  const base = ctx.createLinearGradient(0, 0, W * 0.4, H);
  const stops = light ? ["#dfe7fb", "#e6e0f7", "#efe1f2"] : ["#1a2366", "#3b2f93", "#5b3aa6"];
  base.addColorStop(0, stops[0]);
  base.addColorStop(0.55, stops[1]);
  base.addColorStop(1, stops[2]);
  ctx.fillStyle = base;
  ctx.fillRect(0, 0, W, H);
  const blobs: [number, number, number, string, number][] = light
    ? [
        [180, 980, 900, "#9fc2ff", 0.8],
        [80, 120, 700, "#c6d4ff", 0.8],
        [1500, 160, 820, "#d4cbfa", 0.7],
        [1780, 1060, 900, "#f6c6e8", 0.8],
        [1100, 1000, 600, "#d9c3f5", 0.6],
        [860, 520, 650, "#e4dcfb", 0.5],
      ]
    : [
        [180, 980, 900, "#2f7bff", 0.95],
        [80, 120, 700, "#1f3fb8", 0.9],
        [1500, 160, 820, "#3a2a9a", 0.8],
        [1780, 1060, 900, "#e07ccf", 0.85],
        [1100, 1000, 600, "#a46be0", 0.6],
        [860, 520, 650, "#6a4bd6", 0.45],
      ];
  for (const [x, y, r, color, alpha] of blobs) {
    const g = ctx.createRadialGradient(x, y, 0, x, y, r);
    g.addColorStop(0, hexA(color, alpha));
    g.addColorStop(1, hexA(color, 0));
    ctx.fillStyle = g;
    ctx.fillRect(0, 0, W, H);
  }
  // Darken a little, so white words read on it, or lighten, for dark ones.
  ctx.fillStyle = light ? "rgba(250, 249, 252, 0.3)" : "rgba(6, 8, 24, 0.28)";
  ctx.fillRect(0, 0, W, H);
  return c;
}

const hexA = (h: string, a: number) => {
  const n = parseInt(h.slice(1), 16);
  return `rgba(${(n >> 16) & 255}, ${(n >> 8) & 255}, ${n & 255}, ${a})`;
};

/** Film grain: a few tiles of noise, a different one each frame. */
export class Grain {
  private ctx: CanvasRenderingContext2D;
  private tiles: HTMLCanvasElement[] = [];
  private scale: number;

  constructor(parent: HTMLElement, scale: number) {
    this.scale = scale;
    this.ctx = canvas2d(parent, "layer grain", scale).ctx;
    const rand = random(7);
    for (let i = 0; i < 6; i++) {
      const tile = document.createElement("canvas");
      tile.width = tile.height = 256;
      const t = tile.getContext("2d")!;
      const image = t.createImageData(256, 256);
      for (let p = 0; p < image.data.length; p += 4) {
        const v = 128 + (rand() + rand() + rand() - 1.5) * 120;
        image.data[p] = image.data[p + 1] = image.data[p + 2] = v;
        image.data[p + 3] = 255;
      }
      t.putImageData(image, 0, 0);
      this.tiles.push(tile);
    }
  }

  draw(frame: number, amount = 1) {
    const ctx = this.ctx;
    ctx.setTransform(1, 0, 0, 1, 0, 0);
    ctx.clearRect(0, 0, ctx.canvas.width, ctx.canvas.height);
    if (amount <= 0) return;
    const pattern = ctx.createPattern(this.tiles[frame % this.tiles.length], "repeat")!;
    const rand = random(frame * 31 + 1);
    pattern.setTransform(new DOMMatrix().translate(rand() * 256, rand() * 256));
    ctx.globalAlpha = 0.07 * amount;
    ctx.fillStyle = pattern;
    ctx.fillRect(0, 0, ctx.canvas.width, ctx.canvas.height);
    ctx.globalAlpha = 1;
    ctx.setTransform(this.scale, 0, 0, this.scale, 0, 0);
  }
}

/** Drawing helpers for the effects canvases. */
export const fx = {
  glow(ctx: CanvasRenderingContext2D, x: number, y: number, r: number, color: RGB, alpha: number) {
    if (alpha <= 0.001 || r <= 0) return;
    color = tone(color);
    alpha *= glowAlpha;
    const g = ctx.createRadialGradient(x, y, 0, x, y, r);
    g.addColorStop(0, rgba(color, alpha));
    g.addColorStop(0.35, rgba(color, alpha * 0.4));
    g.addColorStop(1, rgba(color, 0));
    ctx.fillStyle = g;
    ctx.fillRect(x - r, y - r, r * 2, r * 2);
  },
  ring(ctx: CanvasRenderingContext2D, x: number, y: number, r: number, width: number, color: RGB, alpha: number, blur = 0) {
    if (alpha <= 0.001 || r <= 0 || width <= 0) return;
    color = tone(color);
    alpha *= light ? 0.75 : 1;
    ctx.save();
    ctx.strokeStyle = rgba(color, alpha);
    ctx.lineWidth = width;
    if (blur) {
      ctx.shadowColor = rgba(color, alpha);
      ctx.shadowBlur = blur;
    }
    ctx.beginPath();
    ctx.arc(x, y, r, 0, Math.PI * 2);
    ctx.stroke();
    ctx.restore();
  },
  /** A torrent piece: a small rounded square, like the site's label dots, with a streak behind it. */
  piece(ctx: CanvasRenderingContext2D, x: number, y: number, vx: number, vy: number, size: number, color: RGB, alpha: number) {
    if (alpha <= 0.002) return;
    color = tone(color);
    const speed = Math.hypot(vx, vy);
    if (speed > 1) {
      const g = ctx.createLinearGradient(x, y, x - vx, y - vy);
      g.addColorStop(0, rgba(color, alpha * 0.8));
      g.addColorStop(1, rgba(color, 0));
      ctx.strokeStyle = g;
      ctx.lineWidth = size * 0.8;
      ctx.lineCap = "round";
      ctx.beginPath();
      ctx.moveTo(x, y);
      ctx.lineTo(x - vx, y - vy);
      ctx.stroke();
    }
    ctx.save();
    ctx.translate(x, y);
    ctx.rotate(Math.atan2(vy, vx));
    ctx.fillStyle = rgba(color, alpha);
    ctx.shadowColor = rgba(color, alpha);
    ctx.shadowBlur = size * 3;
    roundRect(ctx, -size / 2, -size / 2, size, size, size * 0.28);
    ctx.fill();
    ctx.restore();
  },
};

export function roundRect(ctx: CanvasRenderingContext2D, x: number, y: number, w: number, h: number, r: number) {
  ctx.beginPath();
  ctx.roundRect(x, y, w, h, r);
}
