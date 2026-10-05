// The film's two looks: night, as on the website's dark stages, or paper, as
// on its pages, with ?theme=light. The app's own panel and windows are in
// dark mode either way, as in its screenshots.

import type { RGB } from "./lib/time";

export const light = new URLSearchParams(location.search).get("theme") === "light";
if (light) document.documentElement.dataset.theme = "light";

/**
 * A colour of light, as it shows on the stage. On night, as it is. On paper,
 * light doesn't show, so it becomes the colour itself: deeper, and white
 * becomes the accent blue.
 */
export function tone(c: RGB): RGB {
  if (!light) return c;
  const [r, g, b] = c.map((v) => v / 255);
  const max = Math.max(r, g, b);
  const min = Math.min(r, g, b);
  const l = (max + min) / 2;
  let h = 222 / 360;
  let s = (max - min) / (1 - Math.abs(2 * l - 1) || 1);
  if (max - min > 0.04) {
    const d = max - min;
    h = max === r ? ((g - b) / d + (g < b ? 6 : 0)) / 6 : max === g ? ((b - r) / d + 2) / 6 : ((r - g) / d + 4) / 6;
  }
  if (s < 0.3 || max - min <= 0.04) s = 0.85;
  return hsl(h, Math.max(s, 0.7), 0.52);
}

/** How strong a light shows on the stage: on paper, softer. */
export const glowAlpha = light ? 0.55 : 1;

function hsl(h: number, s: number, l: number): RGB {
  const q = l < 0.5 ? l * (1 + s) : l + s - l * s;
  const p = 2 * l - q;
  const channel = (t: number) => {
    if (t < 0) t += 1;
    if (t > 1) t -= 1;
    if (t < 1 / 6) return p + (q - p) * 6 * t;
    if (t < 1 / 2) return q;
    if (t < 2 / 3) return p + (q - p) * (2 / 3 - t) * 6;
    return p;
  };
  return [channel(h + 1 / 3) * 255, channel(h) * 255, channel(h - 1 / 3) * 255];
}
