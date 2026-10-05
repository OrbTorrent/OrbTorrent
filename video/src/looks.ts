// How the orbs look through the film: how full, how lively, which colours,
// and when they flash. The colours mean what they mean in the app: blue while
// downloading, amber while waiting for the VPN, grey while held, green once
// finished.

import { appearance, integrate, type PaletteName } from "./lib/orb";
import { cue, stops } from "./cues";
import { ease, keys, pulse } from "./lib/time";

const heroLevel = (t: number) =>
  keys(t, [
    [0, 1],
    [cue.launch + 0.15, 1],
    [cue.land - 0.05, 0.62],
    [cue.whip - 0.05, 0.62],
    [cue.whip - 0.03, 0.05, ease.linear],
    [cue.absorb, 0.05],
    [cue.absorb + 1.6, 0.42, ease.outCubic],
    [cue.drop, 0.5, ease.linear],
    [cue.back, 0.5],
    [cue.fake - 0.1, 0.64, ease.outCubic],
    [cue.fake - 0.02, 0.64],
    [cue.fake, 0.05, ease.linear],
    [stops[2], 0.05],
    [stops[3], 1, ease.inOutCubic],
    [cue.finale - 0.6, 1],
    [cue.finale, 0.7],
  ]);

const heroEnergy = (t: number) =>
  keys(t, [
    [0, 0.35],
    [cue.full - 0.05, 0.35],
    [cue.full + 0.2, 1],
    [cue.launch, 1],
    [cue.land, 0.8],
    [cue.absorb, 1],
    [cue.drop, 1],
    [cue.drop + 0.15, 0.25],
    [cue.back, 0.25],
    [cue.back + 0.25, 0.95],
    [cue.fake - 0.02, 0.95],
    [cue.fake, 0.1, ease.linear],
    [stops[2] - 0.05, 0.1],
    [stops[2] + 0.05, 1],
    [cue.finished, 0.6],
    [cue.finale, 0.8],
  ]);

const heroSaturation = (t: number) => keys(t, [[cue.fake - 0.02, 1], [cue.fake, 0.2, ease.linear], [cue.flip + 0.05, 0.2], [cue.flip + 0.1, 1, ease.linear]]);

const heroPalette: [number, PaletteName, number][] = [
  [0, "active", 0],
  [cue.drop, "waiting", 0.22],
  [cue.back, "active", 0.35],
  [cue.done, "finished", 0.3],
  [cue.finale - 0.55, "active", 0.55],
];

const heroBloom = (t: number) =>
  0.18 * keys(t, [[0, 0], [cue.full - 1.2, 1], [cue.full, 1], [cue.full + 0.3, 0]]) +
  pulse(t, cue.full - 0.05, 1.0) +
  0.7 * pulse(t, cue.absorb - 0.05, 0.6) +
  0.5 * pulse(t, cue.back, 0.7) +
  0.6 * pulse(t, stops[1], 0.35) +
  0.6 * pulse(t, stops[3], 0.35) +
  pulse(t, cue.finished, 1.2) +
  cue.facts.reduce((sum, at) => sum + 0.45 * pulse(t, at - 0.02, 0.4), 0) +
  0.8 * pulse(t, cue.seat - 0.02, 0.7) +
  0.55 * pulse(t, cue.shine, 1.1);

// The flow of light quickens with energy and stops while held; the globe
// turns a little faster than in the app, so it reads in a short film.
const heroFlow = integrate((t) => (heroSaturation(t) < 0.5 ? 0.03 : 0.25 + 1.15 * heroEnergy(t)));
const heroSpin = integrate((t) => ((2 * Math.PI) / 30) * (2.4 + 3 * keys(t, [[cue.launch + 0.1, 0], [cue.launch + 0.5, 1], [cue.land - 0.05, 0]])));

export const heroLook = (t: number) =>
  appearance(t, {
    level: heroLevel,
    energy: heroEnergy,
    saturation: heroSaturation,
    bloom: heroBloom,
    palette: heroPalette,
    phase: heroFlow,
    spin: heroSpin,
  });

// The menu bar's orb, in scene 2.
const miniFlow = integrate(() => 1.2);
const miniSpin = integrate(() => ((2 * Math.PI) / 30) * 2.4);
export const miniLook = (t: number) =>
  appearance(t, {
    level: (t) => keys(t, [[cue.land, 0.62], [cue.whip + 0.45, 0.7, ease.linear]]),
    energy: () => 0.85,
    saturation: () => 1,
    bloom: (t) => 0.8 * pulse(t, cue.land - 0.02, 0.5),
    palette: [[0, "active", 0]],
    phase: (t) => heroFlow(cue.land) + miniFlow(t) - miniFlow(cue.land),
    spin: (t) => heroSpin(cue.land) + miniSpin(t) - miniSpin(cue.land),
  });

// The orb in the library's inspector, in scene 2b: Tears of Steel, finished
// and sharing back, so full and green.
const sideFlow = integrate(() => 0.8);
const sideSpin = integrate(() => ((2 * Math.PI) / 30) * 2.4);
export const sideLook = (t: number) =>
  appearance(t, {
    level: () => 1,
    energy: () => 0.55,
    saturation: () => 1,
    bloom: (t) => 0.6 * pulse(t, cue.select + 0.06, 0.5),
    palette: [[0, "finished", 0]],
    phase: sideFlow,
    spin: sideSpin,
  });
