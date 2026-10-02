// The orb's colours, the same as the app's OrbPalette.swift.

export type RGB = [number, number, number];

/** deep, ambient ×3, veils ×3, glow: the order OrbMotion blends them in. */
export type Palette = [RGB, RGB, RGB, RGB, RGB, RGB, RGB, RGB];

export const palettes = {
  /** Downloading, and the resting logo: blue. */
  active: [
    [0.03, 0.04, 0.16],
    [0.04, 0.18, 0.68], [0.15, 0.08, 0.5], [0.02, 0.4, 0.8],
    [0.42, 0.9, 1.0], [0.66, 0.46, 1.0], [0.3, 0.62, 1.0],
    [0.22, 0.52, 1.0],
  ],
  /** Finished and seeding: green. */
  finished: [
    [0.01, 0.09, 0.1],
    [0.02, 0.4, 0.36], [0.03, 0.22, 0.4], [0.05, 0.48, 0.3],
    [0.46, 1.0, 0.78], [0.3, 0.88, 1.0], [0.66, 1.0, 0.56],
    [0.2, 0.85, 0.55],
  ],
  /** Waiting for peers, checking or queued: amber. */
  waiting: [
    [0.42, 0.14, 0.03],
    [0.92, 0.46, 0.06], [0.8, 0.28, 0.1], [1.0, 0.64, 0.14],
    [1.0, 0.82, 0.4], [1.0, 0.62, 0.26], [1.0, 0.5, 0.4],
    [1.0, 0.6, 0.15],
  ],
  /** Something went wrong: red. */
  failed: [
    [0.13, 0.02, 0.03],
    [0.56, 0.06, 0.1], [0.38, 0.04, 0.2], [0.64, 0.16, 0.08],
    [1.0, 0.52, 0.46], [1.0, 0.32, 0.38], [1.0, 0.62, 0.42],
    [1.0, 0.25, 0.25],
  ],
} satisfies Record<string, Palette>;

export type PaletteName = keyof typeof palettes;

export const toLinear = (c: number) => (c <= 0.04045 ? c / 12.92 : ((c + 0.055) / 1.055) ** 2.4);
export const toSRGB = (c: number) => (c <= 0.0031308 ? c * 12.92 : 1.055 * c ** (1 / 2.4) - 0.055);

/** SwiftUI's Color.Resolved holds linear sRGB, so the app blends and mixes in linear. */
export const linear = (p: Palette): Palette => p.map((c) => c.map(toLinear) as RGB) as Palette;
