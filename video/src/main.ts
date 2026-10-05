// OrbTorrent's launch film: 57 seconds at 60 frames a second, drawn one frame
// at a time from the timeline, so a browser can render it exactly. With
// ?preview, it plays in real time with its soundtrack, and can be scrubbed.

import "./theme";
import { cue, duration, fps } from "./cues";
import { h } from "./lib/dom";
import { VideoOrb } from "./lib/orb";
import { canvas2d, Grain, Stage, type StageState } from "./lib/stage";
import { drift, ease, hex, keys, mixRGB, pulse, seg, type RGB } from "./lib/time";
import { heroLook, miniLook, sideLook } from "./looks";
import { soundtrack } from "./audio";
import type { Camera, Context, Place, Scene, StageAdd } from "./scenes/types";
import { ignition } from "./scenes/s1-opening";
import { menubar } from "./scenes/s2-menubar";
import { library } from "./scenes/s2b-library";
import { magnet } from "./scenes/s3-magnet";
import { vpnScene } from "./scenes/s4-vpn";
import { fake } from "./scenes/s5-fake";
import { extensions } from "./scenes/s6-extensions";
import { factsScene } from "./scenes/s7-facts";
import { finale } from "./scenes/s8-finale";

const scale = Math.min(window.devicePixelRatio || 1, 2);
const preview = new URLSearchParams(location.search).has("preview");

// The layers, back to front.
const viewport = h("div", { id: "viewport" });
document.body.append(viewport);
const stage = new Stage(viewport, scale);
const camera = h("div", { id: "camera" });
viewport.append(camera);
const back = canvas2d(camera, "layer", scale);
const layer = h("div", { id: "layer" });
camera.append(layer);
const hero = new VideoOrb(camera, "hero");
const mini = new VideoOrb(camera, "mini");
const side = new VideoOrb(camera, "side");
const front = canvas2d(viewport, "layer", scale);
const grain = new Grain(viewport, scale);
viewport.append(h("div", { id: "vignette" }));
const fade = h("div", { id: "fade" });
viewport.append(fade);
const defsHolder = document.createElementNS("http://www.w3.org/2000/svg", "svg");
defsHolder.setAttribute("width", "0");
defsHolder.setAttribute("height", "0");
defsHolder.style.position = "absolute";
const defs = document.createElementNS("http://www.w3.org/2000/svg", "defs");
defsHolder.append(defs);
document.body.append(defsHolder);

const ctx: Context = { camera, layer, defs, back: back.ctx, front: front.ctx };

// The scenes. Scene 2 goes first, as scene 1 flies the orb to its menu bar.
const s2 = menubar(ctx);
const s1 = ignition(ctx, s2.slot);
const s2b = library(ctx, s2.openApp);
const s3 = magnet(ctx);
const s4 = vpnScene(ctx);
const s5 = fake(ctx);
const s6 = extensions(ctx);
const s7 = factsScene(ctx);
const s8 = finale(ctx);
const scenes: Scene[] = [s1.scene, s2.scene, s2b.scene, s3.scene, s4.scene, s5.scene, s6.scene, s7.scene, s8.scene];

// Which scene places the hero orb when.
const heroTrack: [number, number, (t: number) => Place | null][] = [
  [0, cue.land, s1.hero],
  [cue.whip - 0.15, cue.toVpn, s3.hero],
  [cue.toVpn, cue.fake, s4.hero],
  [cue.fake, cue.flip + 0.3, s5.hero],
  [cue.flip + 0.3, cue.finished - 0.05, s6.hero],
  [cue.finished - 0.05, cue.finale, s7.hero],
  [cue.finale, duration + 1, s8.hero],
];

// The stage's colour follows the orb's state.
const tints: [number, string, number][] = [
  [0, "#3885ff", 0],
  [cue.drop, "#ff9926", 0.18],
  [cue.back, "#3885ff", 0.35],
  [cue.fake, "#8d93a8", 0],
  [cue.exe, "#ff4040", 0.08],
  [cue.held, "#8d93a8", 0.5],
  [cue.code, "#3885ff", 0.3],
  [cue.done, "#33d98c", 0.3],
  [cue.finale - 0.55, "#3885ff", 0.55],
];
const tintAt = (t: number): RGB => {
  let colour = hex(tints[0][1]);
  for (const [at, value, length] of tints) {
    if (t < at) break;
    colour = mixRGB(colour, hex(value), length ? ease.inOutSine(seg(t, at, at + length)) : 1);
  }
  return colour;
};
const glowAt = (t: number) =>
  keys(t, [
    [0, 0], [cue.full - 0.3, 0.08], [cue.full + 0.15, 1],
    [cue.full + 0.9, 0.6], [cue.launch + 0.4, 0.5], [cue.land, 0.45],
    [cue.drop, 0.55], [cue.drop + 0.2, 0.85], [cue.back, 0.6], [cue.fake, 0.55],
    [cue.finished, 1], [cue.finished + 0.9, 0.7], [cue.finale, 0.9], [cue.seat, 1.05], [cue.seat + 1, 0.75],
  ]) + cue.facts.reduce((sum, at) => sum + 0.25 * pulse(t, at, 0.45), 0);

function render(t: number, frame: number) {
  // Scenes, then the camera they ask for.
  back.clear();
  front.clear();
  const add: StageAdd = { ripples: [] };
  const cam: Required<Camera> = { x: 0, y: 0, s: 1, ox: 960, oy: 540, glitch: 0 };
  for (const scene of scenes) {
    const on = t >= scene.from && t < scene.to;
    scene.root.style.visibility = on ? "visible" : "hidden";
    if (!on) continue;
    scene.update(t);
    scene.stage?.(t, add);
    const c = scene.camera?.(t);
    if (c) {
      cam.x += c.x ?? 0;
      cam.y += c.y ?? 0;
      if (c.s !== undefined && c.s !== 1) {
        cam.s *= c.s;
        cam.ox = c.ox ?? cam.ox;
        cam.oy = c.oy ?? cam.oy;
      }
      cam.glitch = Math.max(cam.glitch, c.glitch ?? 0);
    }
  }
  cam.x += drift(t * 0.5, 1) * 5;
  cam.y += drift(t * 0.5, 2) * 3.5;
  camera.style.transformOrigin = `${cam.ox}px ${cam.oy}px`;
  camera.style.transform = `translate3d(${cam.x.toFixed(2)}px, ${cam.y.toFixed(2)}px, 0) scale(${cam.s.toFixed(4)})`;
  const g = cam.glitch;
  camera.style.filter = g > 0.02 ? `drop-shadow(${(9 * g).toFixed(1)}px 0 0 rgba(255,40,90,${(0.6 * g).toFixed(2)})) drop-shadow(${(-9 * g).toFixed(1)}px 0 0 rgba(40,220,255,${(0.6 * g).toFixed(2)}))` : "none";

  // The orbs.
  let place: Place | null = null;
  for (const [from, to, at] of heroTrack) if (t >= from && t < to) place = at(t);
  if (place) hero.draw(place.x, place.y, place.d, heroLook(t), { opacity: place.opacity ?? 1, sx: place.sx ?? 1, sy: place.sy ?? 1, rotate: place.rotate ?? 0, stretch: place.stretch ?? 1, angle: place.angle ?? 0, blur: place.blur ?? 0, brightness: place.brightness ?? 1, mask: place.mask ?? "" });
  else hero.draw(0, 0, 0, null);
  const m = s2.mini(t);
  if (m) mini.draw(m.x, m.y, m.d, miniLook(t), { sx: m.sx, sy: m.sy, blur: m.blur ?? 0 });
  else mini.draw(0, 0, 0, null);
  const o = s2b.orb(t);
  if (o) side.draw(o.x, o.y, o.d, sideLook(t), { opacity: o.opacity ?? 1 });
  else side.draw(0, 0, 0, null);

  // Effects.
  for (const scene of scenes) if (t >= scene.from && t < scene.to) scene.effects?.(t);

  // The stage behind it all.
  const tint = tintAt(t);
  const state: StageState = {
    tint,
    glow: glowAt(t),
    dots: keys(t, [[cue.full, 0], [cue.full + 0.9, 1, ease.outCubic]]),
    shift: add.shift ?? 0,
    spot: place && (place.opacity ?? 1) > 0 && place.d > 40 ? { x: place.x, y: place.y, r: place.d * 2.4, alpha: 0.22 * (place.opacity ?? 1) * (place.spot ?? 1) } : undefined,
    ripples: add.ripples,
    wallpaper: add.wallpaper ?? 0,
    wallpaperX: add.wallpaperX ?? 0,
    wallpaperBlur: add.wallpaperBlur ?? 0,
    light: 1,
  };
  stage.draw(state);
  grain.draw(frame);
  fade.style.opacity = ease.inOutSine(seg(t, cue.out, duration)).toFixed(3);
}

// Waits for the fonts, pictures and shaders.
async function ready() {
  await Promise.all([
    document.fonts.load('500 100px "Geist Variable"'),
    document.fonts.load('500 20px "SF Mono Local"'),
    document.fonts.ready,
    ...[...document.images].map((img) => (img.complete ? null : new Promise((r) => { img.onload = img.onerror = r; }))),
  ]);
  await new Promise<void>((resolve) => {
    const check = () => (hero.ready && mini.ready && side.ready ? resolve() : requestAnimationFrame(check));
    check();
  });
  // Lay out every scene once before measuring anything.
  for (const scene of scenes) scene.root.style.visibility = "hidden";
  render(0, 0);
}

const nextPaint = () => new Promise<void>((r) => requestAnimationFrame(() => requestAnimationFrame(() => r())));

/** The soundtrack, normalised to -1.5 dBFS, as a 16-bit stereo WAV in base64. */
async function audio(): Promise<string> {
  const buffer = await soundtrack();
  return wav(buffer);
}

function wav(buffer: AudioBuffer) {
  const channels = [buffer.getChannelData(0), buffer.getChannelData(1)];
  let peak = 0;
  for (const data of channels) for (let i = 0; i < data.length; i++) peak = Math.max(peak, Math.abs(data[i]));
  const gain = peak > 0 ? 0.841 / peak : 1;
  const frames = buffer.length;
  const bytes = new DataView(new ArrayBuffer(44 + frames * 4));
  const text = (at: number, s: string) => [...s].forEach((c, i) => bytes.setUint8(at + i, c.charCodeAt(0)));
  text(0, "RIFF");
  bytes.setUint32(4, 36 + frames * 4, true);
  text(8, "WAVEfmt ");
  bytes.setUint32(16, 16, true);
  bytes.setUint16(20, 1, true);
  bytes.setUint16(22, 2, true);
  bytes.setUint32(24, buffer.sampleRate, true);
  bytes.setUint32(28, buffer.sampleRate * 4, true);
  bytes.setUint16(32, 4, true);
  bytes.setUint16(34, 16, true);
  text(36, "data");
  bytes.setUint32(40, frames * 4, true);
  for (let i = 0; i < frames; i++) {
    for (let c = 0; c < 2; c++) {
      const v = Math.max(-1, Math.min(1, channels[c][i] * gain));
      bytes.setInt16(44 + i * 4 + c * 2, Math.round(v * 32767), true);
    }
  }
  let binary = "";
  const u8 = new Uint8Array(bytes.buffer);
  for (let i = 0; i < u8.length; i += 0x8000) binary += String.fromCharCode(...u8.subarray(i, i + 0x8000));
  return btoa(binary);
}

const loaded = ready();
(window as unknown as Record<string, unknown>).film = {
  fps,
  duration,
  frames: Math.round(duration * fps),
  ready: () => loaded,
  async seek(frame: number) {
    render(frame / fps, frame);
    await nextPaint();
  },
  audio,
};

// In the preview: fit the window, play with sound, scrub.
if (preview) {
  const fit = () => {
    const k = Math.min(window.innerWidth / 1920, (window.innerHeight - 56) / 1080);
    viewport.style.transform = `scale(${k})`;
  };
  fit();
  addEventListener("resize", fit);
  const bar = h("div", { id: "controls" });
  const play = h("button", {}, "Play");
  const range = h("input", { type: "range", min: "0", max: String(duration * fps), value: "0", step: "1" }) as HTMLInputElement;
  const time = h("span", {}, "0.00");
  bar.append(play, range, time);
  document.body.append(bar);
  let audioContext: AudioContext | null = null;
  let source: AudioBufferSourceNode | null = null;
  let music: AudioBuffer | null = null;
  let startedAt = 0;
  let from = 0;
  let playing = false;
  const show = (t: number) => {
    const frame = Math.min(duration * fps - 1, Math.floor(t * fps));
    render(frame / fps, frame);
    range.value = String(frame);
    time.textContent = (frame / fps).toFixed(2);
  };
  const stop = () => {
    source?.stop();
    source = null;
    playing = false;
    play.textContent = "Play";
  };
  const tick = () => {
    if (!playing || !audioContext) return;
    const t = from + audioContext.currentTime - startedAt;
    if (t >= duration) return stop();
    show(t);
    requestAnimationFrame(tick);
  };
  play.addEventListener("click", async () => {
    if (playing) return stop();
    audioContext ??= new AudioContext({ sampleRate: 48000 });
    play.textContent = "…";
    music ??= await soundtrack();
    from = Number(range.value) / fps;
    if (from >= duration - 0.05) from = 0;
    source = audioContext.createBufferSource();
    source.buffer = music;
    source.connect(audioContext.destination);
    startedAt = audioContext.currentTime + 0.05;
    source.start(startedAt, from);
    playing = true;
    play.textContent = "Pause";
    requestAnimationFrame(tick);
  });
  range.addEventListener("input", () => {
    stop();
    show(Number(range.value) / fps);
  });
  addEventListener("keydown", (e) => {
    if (e.key === " ") { e.preventDefault(); play.click(); }
    if (e.key === "ArrowRight") { stop(); show(Number(range.value) / fps + (e.shiftKey ? 1 : 1 / fps)); }
    if (e.key === "ArrowLeft") { stop(); show(Number(range.value) / fps - (e.shiftKey ? 1 : 1 / fps)); }
  });
  loaded.then(() => show(Number(new URLSearchParams(location.search).get("t") ?? 0)));
}
