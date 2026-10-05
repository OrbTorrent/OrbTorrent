// 6. The held card turns over into an extension's code, typed out, and a
// download travels the extension pipeline: checked before it starts,
// downloaded, checked after it finishes, done. "Every download, checked.
// Build your own in TypeScript."

import { cue, stops } from "../cues";
import { h, put, rise, words } from "../lib/dom";
import { icon } from "../lib/icons";
import { fx } from "../lib/stage";
import { ease, hex, lerp, seg, softOut, spring } from "../lib/time";
import type { Context, Place, Scene } from "./types";

// The starter extension from `npm create @orbtorrent/extension`, shortened.
const code: [string, string][][] = [
  [["k", "import"], ["p", " { "], ["t", "Download"], ["p", ", "], ["t", "Result"], ["p", " } "], ["k", "from"], ["s", ' "@orbtorrent/api"'], ["p", ";"]],
  [],
  [["k", "const"], ["v", " gigabyte"], ["p", " = "], ["n", "1_000_000_000"], ["p", ";"]],
  [],
  [["c", "// Runs before any of a download arrives."]],
  [["k", "export default async function"], ["f", " check"], ["p", "("]],
  [["v", "  download"], ["p", ": "], ["t", "Download"], ["p", ","]],
  [["p", "): "], ["t", "Promise"], ["p", "<"], ["t", "Result"], ["p", "> {"]],
  [["k", "  if"], ["p", " (download.size > "], ["n", "50"], ["p", " * gigabyte) {"]],
  [["k", "    return"], ["p", " { status: "], ["s", '"failed"'], ["p", ", summary: "], ["s", '"Over 50 GB"'], ["p", " };"]],
  [["p", "  }"]],
  [["k", "  return"], ["p", " { status: "], ["s", '"passed"'], ["p", ", summary: "], ["s", '"Within your limit"'], ["p", " };"]],
  [["p", "}"]],
];
const total = code.flat().reduce((n, [, text]) => n + text.length, 0);

const lineY = 952;
const nodes = [
  { x: 250, label: "Added", glyph: "plus" },
  { x: 610, label: "Before it starts", glyph: "hand" },
  { x: 960, label: "Downloading", glyph: "arrowDown" },
  { x: 1310, label: "After it finishes", glyph: "flag" },
  { x: 1670, label: "Done", glyph: "check" },
] as const;

export const doneNode = { x: nodes[4].x, y: lineY };

export function extensions(ctx: Context) {
  const root = h("div", { class: "scene" });

  // The code, in a dark glass editor.
  const pre = h("pre", { class: "s6-code" });
  const spans: { el: HTMLElement; text: string; from: number }[] = [];
  let count = 0;
  code.forEach((line, i) => {
    const row = h("div", { class: "s6-line" }, h("span", { class: "s6-num" }, String(i + 1)));
    for (const [kind, text] of line) {
      const el = h("span", { class: `tok-${kind}` });
      row.append(el);
      spans.push({ el, text, from: count });
      count += text.length;
    }
    if (!line.length) row.append(h("span", {}, "​"));
    pre.append(row);
  });
  const caret = h("span", { class: "s6-caret" });
  const editor = h(
    "div",
    { class: "s6-editor glass-dark" },
    h("div", { class: "s6-bar" }, h("span", { class: "s3-dots" }, h("i"), h("i"), h("i")), h("span", {}, "src/check.ts")),
    pre,
  );
  const editorWrap = h("div", { class: "s6-editor-wrap" }, editor);

  // The words.
  const tag = h("p", { class: "label label-dot", style: "--dot: #3885ff" }, h("span", {}, "Extensions"));
  const tagWrap = h("div", { class: "word" }, tag);
  const title = h("h2", { class: "headline s6-title" });
  const lines = [
    ["Every download,", ""],
    ["checked.", ""],
    ["Build your own", "tone"],
    ["in TypeScript.", "tone"],
  ].map(([text, tone]) => {
    const line = h("span", { class: `line ${tone}` });
    title.append(line);
    return words(line, text);
  });
  const copy = h("div", { class: "s6-copy" }, tagWrap, title);

  // The pipeline, as on the app's Extensions page.
  const track = h("div", { class: "s6-track" });
  const trackFill = h("div", { class: "s6-track-fill" });
  track.append(trackFill);
  const nodeEls = nodes.map((n) => {
    const el = h("div", { class: "s6-node", style: `left:${n.x}px;top:${lineY}px` }, h("span", { class: "s6-node-dot", html: icon(n.glyph as "plus", 22, 2.2) }), h("span", { class: "label s6-node-label" }, n.label));
    return el;
  });
  const checks = [
    { at: 1, name: "Fake Download Check", glyph: "film", tone: "orange", result: "No disguised programs" },
    { at: 3, name: "VirusTotal Scan", glyph: "shieldCheck", tone: "blue", result: "No engine flagged" },
  ].map((c) => {
    const result = h("span", { class: "s6-result" }, h("i", { html: icon("check", 14, 3.4) }), c.result);
    const el = h(
      "div",
      { class: "s6-check glass-dark", style: `left:${nodes[c.at].x}px` },
      h("span", { class: `s6-ext s6-ext-${c.tone}`, html: icon(c.glyph as "film", 22, 2) }),
      h("span", { class: "s6-check-text" }, h("b", {}, c.name), result),
    );
    return { el, result, at: c.at };
  });

  root.append(editorWrap, copy, track, ...nodeEls, ...checks.map((c) => c.el));
  ctx.layer.append(root);

  /** Where the travelling orb is along the pipeline. */
  const along = (t: number) => {
    const holds = [
      [stops[0], stops[0] + 0.05],
      [stops[1], stops[1] + 0.3],
      [stops[2], stops[2] + 0.22],
      [stops[3], stops[3] + 0.3],
      [stops[4], stops[4] + 1],
    ];
    for (let i = 0; i < nodes.length; i++) {
      const [arrive, leave] = holds[i];
      if (t < arrive) {
        if (i === 0) return nodes[0].x;
        const from = holds[i - 1][1];
        return lerp(nodes[i - 1].x, nodes[i].x, ease.inOutCubic(seg(t, from, arrive)));
      }
      if (t < leave) return nodes[i].x;
    }
    return nodes[4].x;
  };

  const update = (t: number) => {
    // The editor turns in from where the card turned away.
    const turn = ease.outCubic(seg(t, cue.flip + 0.24, cue.code + 0.15));
    const out = ease.inCubic(seg(t, cue.finished + 0.02, cue.finished + 0.3));
    editorWrap.style.transform = `perspective(1800px) translate3d(${(70 * (1 - turn)).toFixed(2)}px, ${(-60 * out).toFixed(2)}px, 0) rotateY(${(-90 * (1 - turn)).toFixed(2)}deg) scale(${(1 + 0.12 * out).toFixed(4)})`;
    editorWrap.style.opacity = (turn > 0.01 ? 1 - out : 0).toFixed(3);
    editorWrap.style.filter = out > 0.01 ? `blur(${(out * 18).toFixed(1)}px)` : "none";

    // Typed out, quickly.
    const typedBy = cue.code + 1.6;
    const typed = Math.floor(total * ease.inOutSine(seg(t, cue.code + 0.04, typedBy)));
    let caretAt: HTMLElement | null = null;
    for (const s of spans) {
      const n = Math.max(0, Math.min(s.text.length, typed - s.from));
      s.el.textContent = s.text.slice(0, n);
      if (n > 0) caretAt = s.el;
    }
    if (caretAt && caret.parentElement !== caretAt) caretAt.after(caret);
    caret.style.opacity = t < typedBy || Math.floor(t * 3) % 2 === 0 ? "1" : "0";

    rise([tag], t, cue.code, { length: 0.7 });
    rise(lines.flat(), t, cue.code + 0.08, { stagger: 0.06, length: 0.75 });
    put(copy, { y: -40 * out, o: 1 - out, blur: out * 12 });

    // The pipeline slides up, then the download travels it.
    const x = along(t);
    trackFill.style.width = `${Math.max(0, x - nodes[0].x).toFixed(1)}px`;
    put(track, { o: seg(t, cue.pipeline, cue.pipeline + 0.25) * (1 - out), y: 20 * (1 - softOut(seg(t, cue.pipeline, cue.pipeline + 0.5))) });
    nodeEls.forEach((el, i) => {
      const s = spring(t, cue.pipeline + i * 0.07, 2.6, 0.6);
      put(el, { s: 0.6 + 0.4 * s, o: seg(t, cue.pipeline + i * 0.07, cue.pipeline + 0.12 + i * 0.07) * (1 - out) });
      el.classList.toggle("is-passed", t >= stops[i] + (i === 4 ? 0 : 0.05));
      el.classList.toggle("is-done", i === 4 && t >= stops[4]);
    });
    checks.forEach(({ el, result, at }) => {
      const s = spring(t, cue.pipeline + 0.15 + at * 0.07, 2.4, 0.7);
      el.style.transform = `translate3d(-50%, ${(18 * (1 - s)).toFixed(2)}px, 0)`;
      el.style.opacity = (seg(t, cue.pipeline + 0.15 + at * 0.07, cue.pipeline + 0.3 + at * 0.07) * (1 - out)).toFixed(3);
      const lit = t >= stops[at] + 0.1;
      el.classList.toggle("is-lit", t >= stops[at] - 0.05 && t < stops[at] + 0.8);
      result.style.opacity = seg(t, stops[at] + 0.1, stops[at] + 0.2).toFixed(3);
      result.style.transform = `translate3d(${(8 * (1 - softOut(seg(t, stops[at] + 0.1, stops[at] + 0.4)))).toFixed(2)}px, 0, 0)`;
      void lit;
    });
  };

  const hero = (t: number): Place | null => {
    if (t < stops[0] - 0.12) return null;
    const pop = spring(t, stops[0] - 0.12, 3, 0.55);
    const bump = 1 + 0.25 * Math.sin(Math.PI * seg(t, stops[1], stops[1] + 0.25)) + 0.25 * Math.sin(Math.PI * seg(t, stops[3], stops[3] + 0.25));
    return { x: along(t), y: lineY, d: 54 * pop * bump };
  };

  const scene: Scene = {
    from: cue.flip,
    to: cue.finished + 0.4,
    root,
    update,
    effects(t) {
      for (const at of [1, 3]) {
        const p = seg(t, stops[at] + 0.08, stops[at] + 0.6);
        if (p > 0 && p < 1) fx.ring(ctx.back, nodes[at].x, lineY, 30 + 70 * ease.outExpo(p), 2 * (1 - p), hex("#33d98c"), 0.8 * (1 - p), 10);
      }
      const p = seg(t, stops[4], stops[4] + 0.8);
      if (p > 0 && p < 1) {
        fx.ring(ctx.back, nodes[4].x, lineY, 30 + 1300 * ease.outExpo(p), 4 * (1 - p), hex("#33d98c"), 0.9 * (1 - p), 24);
        fx.glow(ctx.back, nodes[4].x, lineY, 260, hex("#33d98c"), 0.7 * (1 - p));
      }
    },
    stage(t, add) {
      const p = seg(t, stops[4], stops[4] + 1.3);
      if (p > 0 && p < 1) add.ripples.push({ x: nodes[4].x, y: lineY, r: 30 + 1300 * ease.outExpo(seg(t, stops[4], stops[4] + 0.8)), strength: 1 - p, width: 80 });
    },
  };
  return { scene, hero };
}
