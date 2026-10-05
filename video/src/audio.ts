// The soundtrack: "This Minimal Technology" by Coma-Media, from Pixabay, cut
// to the film a bar at a time (see `edit` in cues.ts), with Mixkit's sound
// effects on top and the music muffled while the VPN is down. It's mixed in an
// OfflineAudioContext, so every sound lands on its frame.

import { bar, beat, cue, duration, edit, grid, stops } from "./cues";
import { random } from "./lib/time";
import sounds from "./sounds.json";

type Effect = keyof typeof sounds.effects;

const load = async (ac: BaseAudioContext, path: string) => ac.decodeAudioData(await (await fetch(path)).arrayBuffer());

export async function soundtrack(sampleRate = 48000): Promise<AudioBuffer> {
  const ac = new OfflineAudioContext(2, Math.ceil(duration * sampleRate), sampleRate);
  const names = Object.keys(sounds.effects) as Effect[];
  const [music, ...buffers] = await Promise.all([
    load(ac, `/audio/${sounds.music.file}`),
    ...names.map((name) => load(ac, `/audio/sfx/${sounds.effects[name]}.wav`)),
  ]);
  const effects = Object.fromEntries(names.map((name, i) => [name, { buffer: buffers[i], loudest: loudest(buffers[i]) }])) as Record<Effect, { buffer: AudioBuffer; loudest: number }>;

  const master = ac.createGain();
  master.gain.setValueAtTime(1, cue.out);
  master.gain.linearRampToValueAtTime(0, duration);
  master.connect(ac.destination);

  // The music goes through a filter that muffles it while the VPN is down,
  // and opens again over the beat before it's back.
  const muffle = ac.createBiquadFilter();
  muffle.type = "lowpass";
  muffle.Q.value = 0.6;
  muffle.frequency.setValueAtTime(20000, 0);
  muffle.frequency.setValueAtTime(20000, cue.drop);
  muffle.frequency.exponentialRampToValueAtTime(900, cue.drop + 0.3);
  muffle.frequency.setValueAtTime(900, cue.back - beat);
  muffle.frequency.exponentialRampToValueAtTime(20000, cue.back);
  const loudness = ac.createGain();
  loudness.gain.value = 10 ** (sounds.music.gain / 20);
  muffle.connect(loudness).connect(master);

  // The last chord rings on into a long reverb, under the end card.
  const reverb = ac.createConvolver();
  reverb.buffer = impulse(ac, 4);
  const wet = ac.createGain();
  wet.gain.setValueAtTime(0, 0);
  wet.gain.setValueAtTime(0, cue.seat - 0.02);
  wet.gain.linearRampToValueAtTime(0.45, cue.seat + 0.05);
  loudness.connect(wet).connect(reverb).connect(master);

  // The cut: bars that follow on in the track play as one run, and each run
  // fades in over the moment before its downbeat, so the downbeat lands whole.
  const fade = 0.012;
  const runs: { at: number; from: number; bars: number }[] = [];
  edit.forEach((trackBar, i) => {
    const run = runs[runs.length - 1];
    if (run && edit[i - 1] === trackBar - 1) run.bars++;
    else runs.push({ at: i * bar, from: grid + trackBar * bar, bars: 1 });
  });
  runs.forEach((run, i) => {
    const first = i === 0;
    const last = i === runs.length - 1;
    const start = first ? run.at : run.at - fade;
    const end = last ? duration : run.at + run.bars * bar;
    const gain = ac.createGain();
    gain.gain.setValueAtTime(first ? 1 : 0, start);
    gain.gain.linearRampToValueAtTime(1, run.at);
    if (!last) {
      gain.gain.setValueAtTime(1, end - fade);
      gain.gain.linearRampToValueAtTime(0, end);
    }
    const source = ac.createBufferSource();
    source.buffer = music;
    source.connect(gain).connect(muffle);
    source.start(start, run.from - (run.at - start));
    source.stop(end);
  });

  // ── The effects ────────────────────────────────────────────────────────

  const sfx = ac.createGain();
  sfx.connect(master);

  /**
   * Plays an effect so that the moment `at` seconds into it lands at time `t`,
   * at `level` dB at its loudest.
   */
  const play = (name: Effect, t: number, level: number, { at = 0, pan = 0, from = 0, length = Infinity, fadeOut = 0 } = {}) => {
    const { buffer, loudest } = effects[name];
    let start = t - at;
    let offset = from;
    if (start < 0) {
      offset -= start;
      start = 0;
    }
    const end = Math.min(start + buffer.duration - offset, start + length, duration);
    const gain = ac.createGain();
    const value = 10 ** ((level - loudest) / 20);
    gain.gain.setValueAtTime(value, start);
    if (fadeOut > 0) {
      gain.gain.setValueAtTime(value, end - fadeOut);
      gain.gain.linearRampToValueAtTime(0, end);
    }
    const panner = ac.createStereoPanner();
    panner.pan.value = pan;
    const source = ac.createBufferSource();
    source.buffer = buffer;
    source.connect(gain).connect(panner).connect(sfx);
    source.start(start, offset);
    source.stop(end);
  };

  /** A low boom under a hit. */
  const boom = (t: number, level: number, length = 1.2) => {
    const o = ac.createOscillator();
    o.frequency.setValueAtTime(64, t);
    o.frequency.exponentialRampToValueAtTime(34, t + length);
    const gain = ac.createGain();
    gain.gain.setValueAtTime(0, t);
    gain.gain.linearRampToValueAtTime(level, t + 0.01);
    gain.gain.exponentialRampToValueAtTime(0.001, t + length);
    o.connect(gain).connect(sfx);
    o.start(t);
    o.stop(t + length + 0.05);
  };

  // 1. The first light, the orb lighting up, and the flight.
  play("sparkle", cue.spark + 0.4, -24, { at: 0.04 });
  play("swirl", cue.full, -24, { at: 1.97 });
  play("impact", cue.full, -17, { at: 0.3 });
  boom(cue.full, 0.2, 1.6);
  play("whoosh", cue.land, -21, { at: 0.75, pan: 0.35 });
  // 2. Landing in the menu bar, then the whip to the magnet link.
  play("pop", cue.land, -22, { at: 0.02, pan: 0.6 });
  // 2b. Open App, the window, and a download looked inside.
  play("click", cue.open, -27, { at: 0.005, pan: 0.45 });
  play("swoosh", cue.open + 0.2, -24, { at: 0.11, pan: 0.2 });
  play("click", cue.select, -28, { at: 0.005, pan: -0.1 });
  play("pop", cue.select + 0.12, -27, { at: 0.02, pan: 0.4 });
  play("sweep", cue.whip + 0.2, -21, { at: 0.28, pan: -0.3 });
  // 3. The click, the link pouring into the orb, and down to the diagram.
  play("click", cue.click, -27, { at: 0.005, pan: -0.4 });
  play("pour", cue.absorb, -24, { at: 0.34, pan: 0.3 });
  play("air", cue.toVpn + 0.3, -27, { at: 0.72 });
  // 4. The VPN drops, and is back.
  play("glitch", cue.drop, -18, { at: 0.02 });
  play("fail", cue.drop, -25, { length: 1.8, fadeOut: 0.8 });
  play("powerUp", cue.back, -23, { at: 0.34, length: 1.6, fadeOut: 0.8 });
  play("zoom", cue.fake, -19, { at: 0.52 });
  // 5. The check, the fake, and the hold.
  play("scan", cue.scan, -29, { length: cue.exe - cue.scan, fadeOut: 0.1 });
  play("error", cue.exe, -18, { at: 0.12 });
  play("select", cue.stamp, -23, { at: 0.13 });
  play("swoosh", cue.flip + 0.1, -22, { at: 0.11, pan: 0.3 });
  // 6. The extension typed out, and the pipeline's stops.
  play("typing", cue.code + 0.04, -29, { from: 2, length: 1.6, fadeOut: 0.3, pan: 0.25 });
  const nodeX = [250, 610, 960, 1310];
  stops.slice(0, 4).forEach((at, i) => play("tick", at, -25, { at: 0.005, pan: ((nodeX[i] - 960) / 960) * 0.6 }));
  // 7. Done, on the drop, and the facts.
  boom(cue.done, 0.12, 1.2);
  play("swoosh", cue.facts[2], -27, { at: 0.11, pan: 0.4 });
  // 8. Pulled in to the name, seated on the last chord, and a shine.
  play("swirl", cue.seat, -25, { at: 1.97 });
  boom(cue.seat, 0.15, 2);
  play("sparkle", cue.shine, -29, { at: 0.04, pan: 0.2 });

  return ac.startRendering();
}

/** An effect's loudest moment, in dB, measured over about 20 ms at a time. */
function loudest(buffer: AudioBuffer) {
  const channels = Array.from({ length: buffer.numberOfChannels }, (_, c) => buffer.getChannelData(c));
  const size = 1024;
  let max = 0;
  for (let i = 0; i + size <= buffer.length; i += 256) {
    let sum = 0;
    for (let j = i; j < i + size; j++) {
      let v = 0;
      for (const data of channels) v += data[j];
      v /= channels.length;
      sum += v * v;
    }
    max = Math.max(max, sum / size);
  }
  return 10 * Math.log10(max || 1e-12);
}

/** A reverb's impulse: two channels of noise, fading. */
function impulse(ac: BaseAudioContext, seconds: number) {
  const rand = random(99);
  const length = Math.floor(ac.sampleRate * seconds);
  const buffer = ac.createBuffer(2, length, ac.sampleRate);
  for (let c = 0; c < 2; c++) {
    const data = buffer.getChannelData(c);
    let last = 0;
    for (let i = 0; i < length; i++) {
      const t = i / ac.sampleRate;
      last = last * 0.55 + (rand() * 2 - 1) * 0.45;
      data[i] = last * Math.exp(-t / 0.9) * (t < 0.01 ? t / 0.01 : 1);
    }
  }
  return buffer;
}
