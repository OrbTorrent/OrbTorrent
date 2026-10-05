// 5. A film's name, checked before any of it arrives. The check finds it ends
// in .exe: it's a program dressed as a video. The name drops into the app's
// held download, and it waits for you. "A fake download, stopped before it
// starts."

import { cue } from "../cues";
import { chars, h, put, rise, sink, where, words } from "../lib/dom";
import { icon } from "../lib/icons";
import { fx } from "../lib/stage";
import { ease, hex, hit, random, seg, softOut, spring } from "../lib/time";
import { light as paper } from "../theme";
import type { Context, Place, Scene } from "./types";

const film = "Ocean Life (2026) 1080p WEB-DL";

export function fake(ctx: Context) {
  const root = h("div", { class: "scene" });

  // The big name.
  const tag = h("p", { class: "label label-dot", style: "--dot: #8d93a8" }, h("span", {}, "Before it starts"));
  const tagWrap = h("div", { class: "word s5-tag" }, tag);
  const tile = h("span", { class: "s5-tile", html: icon("film", 50, 1.9) }, h("span", { class: "s5-tile-badge", html: icon("x", 18, 3.4) }));
  const name = h("span", { class: "s5-name" });
  const nameChars = chars(name, `${film}.mp4`, "s5-char");
  const exe = h("span", { class: "s5-exe" });
  const exeChars = chars(exe, ".exe", "s5-char");
  name.append(exe);
  const bracket = h("span", { class: "s5-bracket" });
  const group = h("div", { class: "s5-group" }, tile, name);
  const beam = h("div", { class: "s5-beam" });
  const readouts = [
    h("p", { class: "label label-dot", style: "--dot: #8d93a8" }, h("span", {}, "Fake Download Check · checking 3 files")),
    h("p", { class: "label label-dot s5-problem", style: "--dot: #ff4040" }, h("span", {}, "A program disguised as a video")),
  ];
  const readout = h("div", { class: "s5-readout" }, ...readouts.map((r) => h("div", { class: "word" }, r)));

  // The held download, as in the app's panel.
  const orbSlot = h("span", { class: "s5-orb-slot" });
  const exeRowName = h("span", { class: "s5-file-name" }, `${film}.mp4.exe`);
  const fileRow = (label: HTMLElement | string, size: string) =>
    h("div", { class: "s5-file" }, h("span", { class: "s5-check", html: icon("check", 18, 3.4) }), typeof label === "string" ? h("span", { class: "s5-file-name" }, label) : label, h("span", { class: "s5-size" }, size));
  const exeRow = fileRow(exeRowName, "3.3 MB");
  const exeCheck = exeRow.querySelector<HTMLElement>(".s5-check")!;
  const problem = h(
    "div",
    { class: "s5-box" },
    h("div", { class: "s5-box-head" }, h("span", { class: "s5-x", html: icon("x", 18, 3.4) }), h("b", {}, "1 found a problem")),
    h(
      "div",
      { class: "s5-box-body" },
      h("span", { class: "s5-ext", html: icon("film", 26, 2) }, h("span", { class: "s5-ext-badge", html: icon("x", 11, 4) })),
      h("span", {}, h("b", {}, "Fake Download Check"), h("span", {}, `Contains a program disguised as a video: ${film}.mp4.exe`)),
    ),
  );
  const card = h(
    "div",
    { class: "s5-card glass-dark" },
    h("div", { class: "s5-head" }, orbSlot, h("b", {}, "OrbTorrent"), h("span", { class: "panel-speeds" }, h("i", { class: "down", html: icon("arrowDown", 18, 2.6) }), "2.5 MB/s", h("i", { class: "up", html: icon("arrowUp", 18, 2.6) }), "244 kB/s")),
    h("div", { class: "panel-rule" }),
    h("div", { class: "s5-title" }, h("span", { class: "s5-folder", html: icon("folder", 30, 1.8) }), h("span", {}, h("b", {}, film), h("span", {}, "3 files · 3.4 MB of 3.4 MB selected"))),
    h("div", { class: "s5-files-head" }, h("span", {}, "Files"), h("span", { class: "s5-links" }, "Select All", h("span", {}, "Select None"))),
    exeRow,
    fileRow("English.srt", "84 kB"),
    fileRow("Read Me.txt", "1 kB"),
    problem,
    h("div", { class: "s5-buttons" }, h("span", {}, "Cancel"), h("span", {}, h("i", { html: icon("arrowDown", 18, 2.4) }), "Download Anyway")),
  );
  const heldPill = h("p", { class: "s5-held label label-dot", style: "--dot: #8d93a8" }, h("span", {}, "Held until you decide"));
  const flipper = h("div", { class: "s5-flipper" }, card, heldPill);

  const title = h("h2", { class: "headline s5-title-words" });
  const lines = ["A fake download,", "stopped before", "it starts."].map((text, i) => {
    const line = h("span", { class: i ? "line tone" : "line" });
    title.append(line);
    return words(line, text);
  });
  const titleWords = lines.flat();

  root.append(flipper, title, tagWrap, group, bracket, beam, readout);
  ctx.layer.append(root);

  // Measured once: where the big name sits, and the row it drops into.
  let from: ReturnType<typeof where> | null = null;
  let to: ReturnType<typeof where> | null = null;
  let exeWidth = 0;
  let mp4At = 0;
  const rand = random(17);
  const jitter = Array.from({ length: 12 }, () => (rand() - 0.5) * 18);

  const flip = (t: number) => ease.inCubic(seg(t, cue.flip, cue.flip + 0.24)) * 90;

  const update = (t: number) => {
    if (!from) {
      group.style.transform = "none";
      name.style.transform = "none";
      card.style.transform = "none";
      from = where(name, ctx.camera);
      to = where(exeRowName, ctx.camera);
      exeWidth = where(exe, ctx.camera).w;
      mp4At = where(nameChars[film.length], ctx.camera).x;
    }

    // The name arrives, a character at a time.
    rise([tag], t, cue.fake + 0.05, { length: 0.7 });
    nameChars.forEach((c, i) => {
      const p = softOut(seg(t, cue.fake + 0.06 + i * 0.014, cue.fake + 0.56 + i * 0.014));
      put(c, { y: (1 - p) * 46, o: seg(t, cue.fake + 0.06 + i * 0.014, cue.fake + 0.3 + i * 0.014), blur: (1 - p) * 8 });
      // The scan lights each one as it passes.
      const lit = Math.max(0, 1 - Math.abs(t - (cue.scan + 0.05 + (i / nameChars.length) * (cue.exe - cue.scan - 0.1))) / 0.1);
      c.style.color = lit > 0 ? `color-mix(in srgb, ${paper ? "#2f6bff" : "#9fd6ff"} ${(lit * 100).toFixed(0)}%, ${paper ? "#131316" : "#f3f5ff"})` : "";
    });
    const tp = spring(t, cue.fake + 0.12, 2.6, 0.55);
    put(tile, { s: tp, o: seg(t, cue.fake + 0.12, cue.fake + 0.25) });
    tile.classList.toggle("is-bad", t > cue.exe + 0.05);
    const badge = tile.querySelector<HTMLElement>(".s5-tile-badge")!;
    put(badge, { s: spring(t, cue.exe + 0.05, 3, 0.5) });

    // .exe slams in, and the name shifts to make room.
    const room = ease.outExpo(seg(t, cue.exe, cue.exe + 0.25));
    exeChars.forEach((c, i) => {
      const p = spring(t, cue.exe + i * 0.03, 3.2, 0.55);
      put(c, { s: 1 + (1 - p) * 0.9, o: seg(t, cue.exe + i * 0.03, cue.exe + 0.06 + i * 0.03), y: (1 - p) * -30 });
    });
    const glitch = t > cue.exe && t < cue.exe + 0.16 ? jitter[Math.floor((t - cue.exe) * 60) % jitter.length] : 0;

    // At the hold, the name drops into the card's first file.
    const m = ease.inOutCubic(seg(t, cue.held, cue.held + 0.55));
    const baseX = (exeWidth / 2) * (1 - room) + glitch;
    group.style.transform = `translate3d(${(baseX * (1 - m)).toFixed(2)}px, 0, 0)`;
    group.style.opacity = (1 - seg(t, cue.held + 0.47, cue.held + 0.56)).toFixed(3);
    if (from && to) {
      const k = to.w / from.w;
      name.style.transform = `translate3d(${(m * (to.x - from.x)).toFixed(2)}px, ${(m * (to.cy - from.cy)).toFixed(2)}px, 0) scale(${(1 + (k - 1) * m).toFixed(4)})`;
    }
    put(tile, { s: tp * (1 - m), o: seg(t, cue.fake + 0.12, cue.fake + 0.25) * (1 - seg(t, cue.held, cue.held + 0.2)) });

    // The bracket under .mp4.exe.
    if (from) {
      const b = ease.outExpo(seg(t, cue.exe + 0.08, cue.exe + 0.4));
      bracket.style.left = `${(mp4At + baseX).toFixed(1)}px`;
      bracket.style.top = `${(from.y + from.h + 8).toFixed(1)}px`;
      bracket.style.width = `${(from.x + from.w - mp4At).toFixed(1)}px`;
      put(bracket, { sx: b, sy: 1, o: b * (1 - seg(t, cue.held, cue.held + 0.15)) });
    }

    // The scan beam.
    if (from) {
      const p = ease.inOutSine(seg(t, cue.scan, cue.exe));
      beam.style.left = `${(from.x - 40 + (from.w - exeWidth + 80) * p).toFixed(1)}px`;
      beam.style.top = `${(from.y - 60).toFixed(1)}px`;
      beam.style.height = `${(from.h + 120).toFixed(1)}px`;
      beam.style.opacity = (Math.min(seg(t, cue.scan, cue.scan + 0.08), 1 - seg(t, cue.exe - 0.06, cue.exe + 0.02))).toFixed(3);
    }
    readouts.forEach((r, i) => {
      const start = i ? cue.exe + 0.05 : cue.scan - 0.3;
      const end = i ? cue.held : cue.exe;
      const inP = softOut(seg(t, start, start + 0.5));
      const outP = ease.inCubic(seg(t, end, end + 0.15));
      r.style.transform = `translate3d(0, ${((1 - inP) * 170 - outP * 170).toFixed(2)}%, 0)`;
    });
    put(tagWrap, { o: 1 - seg(t, cue.held, cue.held + 0.2) });

    // The card rises, then flips away to scene 6.
    const c = spring(t, cue.held - 0.06, 2.1, 0.78);
    const angle = flip(t);
    card.style.transform = `translate3d(0, ${(160 * (1 - c)).toFixed(2)}px, 0) rotateY(${angle.toFixed(2)}deg)`;
    card.style.opacity = (seg(t, cue.held - 0.06, cue.held + 0.12) * (angle >= 89.5 ? 0 : 1)).toFixed(3);
    exeRowName.style.opacity = seg(t, cue.held + 0.46, cue.held + 0.56).toFixed(3);
    // Its tick appears once the name has landed beside it.
    put(exeCheck, { s: 0.6 + 0.4 * spring(t, cue.held + 0.5, 3, 0.6), o: seg(t, cue.held + 0.5, cue.held + 0.6) });
    const problemAt = cue.held + 0.35;
    const pb = spring(t, problemAt, 2.6, 0.6);
    problem.style.transform = `scale(${(0.94 + 0.06 * pb).toFixed(4)})`;
    problem.style.opacity = seg(t, problemAt, problemAt + 0.12).toFixed(3);
    problem.style.boxShadow = `0 0 ${(60 * hit(t, problemAt, 0.4) * (t > problemAt ? 1 : 0)).toFixed(1)}px rgba(255,64,64,0.55)`;
    const hp = spring(t, cue.stamp, 3, 0.5);
    heldPill.style.transform = `translate3d(-50%, 0, 0) scale(${(hp * (1 + 0.5 * (1 - seg(t, cue.stamp, cue.stamp + 0.1)))).toFixed(4)}) rotateY(${angle.toFixed(2)}deg)`;
    heldPill.style.opacity = (seg(t, cue.stamp, cue.stamp + 0.06) * (angle >= 89.5 ? 0 : 1)).toFixed(3);

    rise(titleWords, t, cue.held + 0.25, { stagger: 0.06, length: 0.8 });
    sink(titleWords, t, cue.flip - 0.05, { stagger: 0.02, length: 0.28 });
  };

  const hero = (t: number): Place | null => {
    if (t < cue.held - 0.06 || t > cue.flip + 0.25) return null;
    const slot = where(orbSlot, ctx.camera);
    const angle = (flip(t) * Math.PI) / 180;
    return { x: slot.cx, y: slot.cy, d: slot.w, sx: Math.cos(angle), opacity: seg(t, cue.held, cue.held + 0.15) };
  };

  const scene: Scene = {
    from: cue.fake - 0.02,
    to: cue.flip + 0.3,
    root,
    update,
    effects(t) {
      // The flash from the last scene fading.
      const flash = 1 - ease.outCubic(seg(t, cue.fake, cue.fake + 0.55));
      if (t >= cue.fake && flash > 0) {
        ctx.front.fillStyle = `rgba(226, 236, 255, ${flash.toFixed(3)})`;
        ctx.front.fillRect(0, 0, 1920, 1080);
      }
      // A red flare when .exe lands.
      const e = t > cue.exe ? hit(t, cue.exe, 0.3) : 0;
      if (e > 0.01 && from) fx.glow(ctx.back, from.x + from.w - exeWidth / 2, from.cy, 340, hex("#ff4040"), 0.55 * e);
      const s = t > cue.stamp ? hit(t, cue.stamp, 0.25) : 0;
      if (s > 0.01 && to) fx.glow(ctx.back, to.cx + 120, to.y - 60, 500, hex("#8d93a8"), 0.35 * s);
    },
    camera(t) {
      const e = t > cue.exe ? hit(t, cue.exe, 0.08) : 0;
      const s = t > cue.stamp ? hit(t, cue.stamp, 0.1) : 0;
      const rand = random(Math.floor(t * 60) + 3);
      return { x: (e * 18 + s * 8) * (rand() - 0.5), y: s * 10 * (rand() - 0.5), glitch: e > 0.05 ? e * 0.8 : 0 };
    },
  };
  return { scene, hero };
}
