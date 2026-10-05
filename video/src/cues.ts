// The film's timeline, in seconds, shared by the pictures and the soundtrack.
// It's cut to "This Minimal Technology" at 135 beats a minute: a beat is
// 0.444 s, a bar four beats. The story lands on the music: the orb lights up as
// the intro swells, reaches the menu bar as the groove opens, the VPN drops into the quiet of the intro, it's
// back on a phrase's first bar, the download is done as the groove opens
// again, and the orb takes its place in the name as the track ends.

export const fps = 60;
export const bpm = 135;
export const beat = 60 / bpm;
export const bar = 4 * beat;
export const duration = 56.8;

const b = (n: number) => n * beat;

/** Which of the track's bars plays under each of the film's bars. The last one plays on to the end. */
export const edit = [0, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 2, 3, 40, 41, 42, 43, 44, 45, 6, 7, 48, 49, 50, 51, 64];
/** Where the track's first bar starts, in the file. */
export const grid = 0.034;

const seat = b(116);

export const cue = {
  // 1. The orb comes to light as the intro swells, then its name and what it is.
  spark: 0,
  full: b(8),
  name: b(8) + 0.15,
  tagline: b(8) + 0.75,
  launch: b(14),
  // 2. It lands in the menu bar as the groove opens, and the panel drops.
  land: b(16),
  rows: b(16) + 0.45,
  // 2b. Open App: the library window.
  open: b(28),
  select: b(34),
  whip: b(42),
  // 3. A magnet link, clicked.
  magnet: b(42) + 0.3,
  click: b(45),
  absorb: b(46),
  toVpn: b(52),
  // 4. The VPN drops into the quiet, and is back on a phrase's first bar.
  warn: b(57),
  drop: b(60),
  back: b(68),
  zoom: b(72) - 0.55,
  // 5. A fake download, held.
  fake: b(72),
  scan: b(76) - 0.85,
  exe: b(76),
  held: b(78.5),
  stamp: b(79.5),
  flip: b(85.5),
  // 6. Extensions, building to the groove opening again.
  code: b(86),
  pipeline: b(92),
  done: b(100),
  // 7. Finished, then what it is.
  finished: b(100) + 0.1,
  facts: [b(106), b(107.5), b(109), b(110.5), b(112)],
  rise: seat - 1.5,
  // 8. The name, as the track ends.
  finale: seat - 0.5,
  seat,
  lockup: seat + 0.9,
  shine: seat + 2.1,
  out: duration - 1,
} as const;

/** The pipeline's stops in scene 6, for the orb and the blips. */
export const stops = [b(94), b(95.5), b(97), b(98.5), b(100)];
