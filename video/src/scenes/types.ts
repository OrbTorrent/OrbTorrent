import type { Ripple } from "../lib/stage";

export interface Context {
  /** The camera's frame, for measuring where things are. */
  camera: HTMLElement;
  /** Where scenes put their elements. */
  layer: HTMLElement;
  defs: SVGDefsElement;
  /** Effects behind the scenes' elements and over the stage, in the camera. */
  back: CanvasRenderingContext2D;
  /** Effects over everything, on screen. */
  front: CanvasRenderingContext2D;
}

export interface Place {
  x: number;
  y: number;
  d: number;
  opacity?: number;
  sx?: number;
  sy?: number;
  rotate?: number;
  /** Stretched along `angle`, in degrees, as it flies. */
  stretch?: number;
  angle?: number;
  blur?: number;
  /** Lit up past 1, or dimmed. */
  brightness?: number;
  /** A CSS mask over the orb's canvas, in its own pixels, from its top left. */
  mask?: string;
  /** How much it lights the stage behind it, 0 to 1. */
  spot?: number;
}

export interface StageAdd {
  ripples: Ripple[];
  wallpaper?: number;
  wallpaperX?: number;
  wallpaperBlur?: number;
  shift?: number;
}

export interface Scene {
  /** When the scene's elements are on screen. */
  from: number;
  to: number;
  root: HTMLElement;
  update(t: number): void;
  /** Effects drawn behind and in front, called every frame. */
  effects?(t: number): void;
  /** Moves the camera: a shake, a push in, a glitch. */
  camera?(t: number): Camera | null;
  /** Adds to the stage: ripples, the wallpaper, a drift. */
  stage?(t: number, add: StageAdd): void;
}

export interface Camera {
  x?: number;
  y?: number;
  s?: number;
  /** Where it scales from. */
  ox?: number;
  oy?: number;
  /** Colour fringing and jitter, 0 to 1. */
  glitch?: number;
}
