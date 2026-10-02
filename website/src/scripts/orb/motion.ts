// How the orb moves, ported from the app's OrbMotion.swift: the level eases,
// colours blend, the flow speeds up or settles, the globe keeps turning, and
// finishing flashes the glow.

import { linear, palettes, type Palette, type PaletteName } from "./palette";

export type OrbState =
  | { kind: "idle" }
  | { kind: "downloading"; progress: number; energy: number }
  | { kind: "waiting"; progress: number }
  | { kind: "paused"; progress: number }
  | { kind: "seeding" }
  | { kind: "finished" }
  | { kind: "failed"; progress: number };

/** Everything that decides how the orb looks at one moment. */
export interface Appearance {
  level: number;
  phase: number;
  energy: number;
  saturation: number;
  /** In linear sRGB, as SwiftUI's Color.Resolved. */
  palette: Palette;
  bloom: number;
  spin: number;
}

const isFinished = (s: OrbState) => s.kind === "seeding" || s.kind === "finished";
const same = (a: OrbState, b: OrbState) => JSON.stringify(a) === JSON.stringify(b);

interface Target {
  level: number;
  energy: number;
  saturation: number;
  rate: number;
  palette: PaletteName;
}

function target(state: OrbState): Target {
  let t: Target;
  switch (state.kind) {
    case "idle":
      t = { level: 1, energy: 0.35, saturation: 1, rate: 0.22, palette: "active" };
      break;
    case "downloading":
      t = { level: state.progress, energy: 0.5 + 0.5 * state.energy, saturation: 1, rate: 0.45 + 0.8 * state.energy, palette: "active" };
      break;
    case "waiting":
      t = { level: state.progress, energy: 0.3, saturation: 1, rate: 0.2, palette: "waiting" };
      break;
    case "paused":
      t = { level: state.progress, energy: 0.1, saturation: 0.2, rate: 0, palette: "active" };
      break;
    case "seeding":
      t = { level: 1, energy: 0.45, saturation: 1, rate: 0.3, palette: "finished" };
      break;
    case "finished":
      t = { level: 1, energy: 0.4, saturation: 1, rate: 0, palette: "finished" };
      break;
    case "failed":
      t = { level: state.progress, energy: 0.25, saturation: 1, rate: 0.06, palette: "failed" };
      break;
  }
  // Never quite empty, so there's always a little light to see.
  t.level = Math.max(t.level, 0.05);
  return t;
}

/** One slow turn about every 30 seconds, in every state. */
const turnRate = (2 * Math.PI) / 30;

export class OrbMotion {
  private level = 1;
  private energy = 0.35;
  private saturation = 1;
  private rate = 0.3;
  private bloom = 0;
  private phase: number;
  private spin: number;
  private spinRate = 0;
  private palette: Palette = linear(palettes.active);
  private clock = 0;
  private lastState?: OrbState;
  private flashStart?: number;

  /** Each orb starts at its own point in the flow and its own face of the globe. */
  constructor(seed = Math.floor(Math.random() * 1000)) {
    this.phase = (seed % 1000) / 37;
    this.spin = (seed % 628) / 100;
  }

  /** Moves the orb on by `dt` seconds. */
  advance(dt: number, state: OrbState, turnSpeed = 1): Appearance {
    dt = Math.min(Math.max(dt, 0), 0.1);
    this.clock += dt;
    const goal = target(state);
    if (!this.lastState) {
      this.settle(goal);
      this.spinRate = turnRate;
    } else if (!isFinished(this.lastState) && this.lastState.kind !== "idle" && isFinished(state)) {
      this.flashStart = this.clock;
    }
    this.lastState = state;

    const ease = (value: number, to: number, seconds: number) => value + (to - value) * (1 - Math.exp(-dt / seconds));
    this.level = ease(this.level, goal.level, 0.6);
    this.energy = ease(this.energy, goal.energy, 0.8);
    this.saturation = ease(this.saturation, goal.saturation, 0.6);
    // Speed changes ease slowly, so the flow gathers pace and coasts to a stop.
    this.rate = ease(this.rate, goal.rate, 1.1);
    const toward = linear(palettes[goal.palette]);
    const k = 1 - Math.exp(-dt / 0.7);
    this.palette = this.palette.map((c, i) => c.map((v, j) => v + (toward[i][j] - v) * k)) as Palette;
    this.phase += dt * this.rate;
    this.spinRate = ease(this.spinRate, turnRate * turnSpeed, 1.5);
    this.spin += dt * this.spinRate;

    let flash = 0;
    if (this.flashStart !== undefined) {
      const t = (this.clock - this.flashStart) / 1.2;
      if (t < 1) flash = Math.sin(Math.PI * t);
      else this.flashStart = undefined;
    }
    const breathing = state.kind === "seeding" ? 0.3 + 0.3 * Math.sin(this.clock * 1.2) : 0;
    this.bloom = ease(this.bloom, Math.max(breathing, flash), 0.3);
    return this.appearance;
  }

  /** The orb holding still in a state, for Reduce Motion: no easing, no flow and no turning. */
  still(state: OrbState): Appearance {
    this.settle(target(state));
    this.lastState = state;
    this.bloom = 0;
    return this.appearance;
  }

  private settle(goal: Target) {
    this.level = goal.level;
    this.energy = goal.energy;
    this.saturation = goal.saturation;
    this.rate = goal.rate;
    this.palette = linear(palettes[goal.palette]);
  }

  private get appearance(): Appearance {
    return {
      level: this.level, phase: this.phase, energy: this.energy, saturation: this.saturation,
      palette: this.palette, bloom: this.bloom, spin: this.spin,
    };
  }
}

export { same as sameState };
