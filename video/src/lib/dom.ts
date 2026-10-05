// Small helpers for building the scenes' elements and moving them each frame.

import { clamp, seg, softOut, type Ease } from "./time";

type Child = Node | string | null | undefined | false;

export function h(tag: string, attrs: Record<string, string | number> = {}, ...children: Child[]): HTMLElement {
  const el = document.createElement(tag);
  for (const [key, value] of Object.entries(attrs)) {
    if (key === "class") el.className = String(value);
    else if (key === "html") el.innerHTML = String(value);
    else if (key === "style") el.setAttribute("style", String(value));
    else el.setAttribute(key, String(value));
  }
  for (const child of children) if (child) el.append(child);
  return el;
}

export function svg(markup: string): SVGSVGElement {
  const holder = document.createElement("div");
  holder.innerHTML = markup.trim();
  return holder.firstElementChild as SVGSVGElement;
}

/** Sets an element's transform, opacity and blur in one go. */
export function put(
  el: HTMLElement | SVGElement,
  { x = 0, y = 0, s = 1, sx, sy, r = 0, o, blur, z }: { x?: number; y?: number; s?: number; sx?: number; sy?: number; r?: number; o?: number; blur?: number; z?: number },
) {
  const scale = sx !== undefined || sy !== undefined ? `scale(${(sx ?? s).toFixed(4)}, ${(sy ?? s).toFixed(4)})` : `scale(${s.toFixed(4)})`;
  el.style.transform = `translate3d(${x.toFixed(2)}px, ${y.toFixed(2)}px, 0) ${scale} rotate(${r.toFixed(3)}deg)`;
  if (o !== undefined) el.style.opacity = clamp(o).toFixed(4);
  if (blur !== undefined) el.style.filter = blur > 0.05 ? `blur(${blur.toFixed(2)}px)` : "none";
  if (z !== undefined) el.style.zIndex = String(z);
}

/** Splits text into words, each in a mask, so they can rise into view. */
export function words(parent: HTMLElement, text: string, className = ""): HTMLElement[] {
  const inners: HTMLElement[] = [];
  text.split(" ").forEach((word, i, all) => {
    const inner = h("span", { class: "word-in" }, word);
    parent.append(h("span", { class: `word ${className}` }, inner));
    if (i < all.length - 1) parent.append(" ");
    inners.push(inner);
  });
  return inners;
}

/** Splits text into characters. */
export function chars(parent: HTMLElement, text: string, className = "char"): HTMLElement[] {
  return [...text].map((c) => {
    const span = h("span", { class: className }, c === " " ? " " : c);
    parent.append(span);
    return span;
  });
}

/** Words rising out of their masks, one after another. */
export function rise(items: HTMLElement[], t: number, start: number, { stagger = 0.06, length = 0.7, e = softOut, from = 135 }: { stagger?: number; length?: number; e?: Ease; from?: number } = {}) {
  items.forEach((item, i) => {
    const p = e(seg(t, start + i * stagger, start + i * stagger + length));
    item.style.transform = `translate3d(0, ${((1 - p) * from).toFixed(2)}%, 0)`;
  });
}

/** Words leaving upwards through their masks. */
export function sink(items: HTMLElement[], t: number, start: number, { stagger = 0.03, length = 0.35 } = {}) {
  items.forEach((item, i) => {
    const p = seg(t, start + i * stagger, start + i * stagger + length);
    if (p <= 0) return;
    const q = p * p * p;
    item.style.transform = `translate3d(0, ${(-q * 135).toFixed(2)}%, 0)`;
  });
}

/** Where an element is now, in the stage's own pixels. */
export function where(el: Element, camera: HTMLElement) {
  const box = el.getBoundingClientRect();
  const frame = camera.getBoundingClientRect();
  const k = frame.width / 1920;
  return {
    x: (box.left - frame.left) / k,
    y: (box.top - frame.top) / k,
    w: box.width / k,
    h: box.height / k,
    cx: (box.left + box.width / 2 - frame.left) / k,
    cy: (box.top + box.height / 2 - frame.top) / k,
  };
}

/** One SVG filter per element, for blur along the direction of movement. */
let blurs = 0;
export function motionBlur(defs: SVGDefsElement) {
  const id = `motion-${blurs++}`;
  const filter = document.createElementNS("http://www.w3.org/2000/svg", "filter");
  filter.setAttribute("id", id);
  filter.setAttribute("x", "-50%");
  filter.setAttribute("y", "-50%");
  filter.setAttribute("width", "200%");
  filter.setAttribute("height", "200%");
  filter.setAttribute("color-interpolation-filters", "sRGB");
  const blur = document.createElementNS("http://www.w3.org/2000/svg", "feGaussianBlur");
  blur.setAttribute("stdDeviation", "0 0");
  filter.append(blur);
  defs.append(filter);
  return (el: HTMLElement | SVGElement, dx: number, dy = 0) => {
    if (Math.abs(dx) < 0.4 && Math.abs(dy) < 0.4) {
      el.style.filter = "none";
      return;
    }
    blur.setAttribute("stdDeviation", `${Math.abs(dx).toFixed(2)} ${Math.abs(dy).toFixed(2)}`);
    el.style.filter = `url(#${id})`;
  };
}
