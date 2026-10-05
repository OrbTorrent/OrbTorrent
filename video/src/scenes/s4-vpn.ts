// 4. Downloads flow to your Mac through the VPN, never the normal connection.
// The VPN drops: the tunnel snaps, everything turns amber, and downloading
// stops. Then it's back, and so is downloading. Then into the orb.

import { beat, cue } from "../cues";
import { h, put, rise, sink, svg, words } from "../lib/dom";
import { icon } from "../lib/icons";
import { fx } from "../lib/stage";
import { cubic, ease, hex, hit, keys, random, seg, softOut, spring } from "../lib/time";
import type { Context, Place, Scene } from "./types";
import { orbHome } from "./s3-magnet";

export const mac = { x: 620, y: 700, d: 150 };
const vpn = { x: 1180, y: 400 };
const peers = { x: 1700, y: 700 };
/** Where a line from the Mac towards x, y leaves the orb's edge, so it never shows through the glass. */
const rim = (x: number, y: number) => {
  const a = Math.atan2(y - mac.y, x - mac.x);
  return `${(mac.x + Math.cos(a) * mac.d / 2).toFixed(1)} ${(mac.y + Math.sin(a) * mac.d / 2).toFixed(1)}`;
};
const pathA = `M${rim(700, 520)} C 700 520, 940 ${vpn.y}, ${vpn.x} ${vpn.y}`;
const pathB = `M${vpn.x} ${vpn.y} C 1420 ${vpn.y}, 1640 520, ${peers.x} ${peers.y}`;
const pathAll = `${pathA} C 1420 ${vpn.y}, 1640 520, ${peers.x} ${peers.y}`;
const pathNormal = `M${rim(820, 960)} C 820 960, 1500 960, ${peers.x} ${peers.y}`;
const breakAt = 0.56;

export function vpnScene(ctx: Context) {
  const root = h("div", { class: "scene" });
  const peerDots = (() => {
    const rand = random(21);
    return Array.from({ length: 9 }, (_, i) => {
      const a = (i / 9) * Math.PI * 2 + rand() * 0.5;
      const r = i === 0 ? 0 : 46 + rand() * 40;
      return { x: peers.x + Math.cos(a) * r, y: peers.y + Math.sin(a) * r * 0.8, r: 9 + rand() * 7, delay: rand() * 0.25 };
    });
  })();
  const art = svg(`<svg class="s4-art" viewBox="0 0 1920 1080" width="1920" height="1080">
    <defs>
      <linearGradient id="vpn-on" gradientUnits="userSpaceOnUse" x1="${mac.x}" y1="0" x2="${peers.x}" y2="0"><stop offset="0" stop-color="#6be5ff"/><stop offset="1" stop-color="#4c8dff"/></linearGradient>
      <linearGradient id="vpn-off" gradientUnits="userSpaceOnUse" x1="${mac.x}" y1="0" x2="${peers.x}" y2="0"><stop offset="0" stop-color="#ffb85c"/><stop offset="1" stop-color="#ff9926"/></linearGradient>
    </defs>
    <g class="s4-peers">${peerDots.map((p, i) => peerDots.slice(i + 1).filter((_, j) => (i + j) % 3 === 0).map((q) => `<line x1="${p.x}" y1="${p.y}" x2="${q.x}" y2="${q.y}"/>`).join("")).join("")}</g>
    <path class="s4-normal" d="${pathNormal}"/>
    <path class="s4-tunnel s4-a" d="${pathA}"/>
    <path class="s4-tunnel s4-b" d="${pathB}"/>
    <path class="s4-flow" d="${pathAll}"/>
    <g class="s4-packets">${Array.from({ length: 16 }, () => "<circle r='5.5'/>").join("")}</g>
    <g class="s4-dots">${peerDots.map((p) => `<circle cx="${p.x}" cy="${p.y}" r="${p.r}"/>`).join("")}</g>
    <g class="s4-breaks"><path d="M-9 -16 L3 14"/><path d="M5 -14 L17 16"/></g>
    <g class="s4-blocked"><circle r="20"/><path d="M-7 -7 L7 7 M7 -7 L-7 7"/></g>
  </svg>`);
  const [tunnelA, tunnelB, flow, normal] = ["s4-a", "s4-b", "s4-flow", "s4-normal"].map((c) => art.querySelector(`.${c}`) as SVGPathElement);
  const packets = [...art.querySelectorAll<SVGCircleElement>(".s4-packets circle")];
  const dots = [...art.querySelectorAll<SVGCircleElement>(".s4-dots circle")];
  const lines = art.querySelector<SVGGElement>(".s4-peers")!;
  const breaks = art.querySelector<SVGGElement>(".s4-breaks")!;
  const blocked = art.querySelector<SVGGElement>(".s4-blocked")!;

  const lock = h("span", { class: "s4-lock", html: icon("lock", 52, 2) });
  const lockOpen = h("span", { class: "s4-lock", html: icon("lockOpen", 52, 2) });
  const vpnNode = h("div", { class: "s4-vpn glass" }, lock, lockOpen);
  const nodeLabel = (text: string, x: number, y: number) => h("p", { class: "label s4-node-label", style: `left:${x}px;top:${y}px` }, text);
  const labels = [nodeLabel("Your Mac", mac.x, mac.y + 104), nodeLabel("VPN", vpn.x, vpn.y + 92), nodeLabel("Peers", peers.x, peers.y + 112)];
  const normalLabel = h("p", { class: "label s4-normal-label" }, "Normal connection · never used");

  const title = h("h2", { class: "headline s4-title" });
  const lineA = h("span", { class: "line" });
  const lineB = h("span", { class: "line tone" });
  title.append(lineA, lineB);
  const wordsA = words(lineA, "Your VPN drops.");
  const wordsB = words(lineB, "So does downloading.");

  const states = [
    { text: "Downloading through the VPN", tint: "#3885ff", from: cue.toVpn + 0.6, to: cue.drop },
    { text: "VPN dropped · downloading stopped", tint: "#ff9926", from: cue.drop + 0.04, to: cue.back },
    { text: "Back on the VPN · downloading", tint: "#3885ff", from: cue.back + 0.08, to: 99 },
  ];
  const statusEls = states.map((s) => h("p", { class: "label label-dot", style: `--dot: ${s.tint}` }, h("span", {}, s.text)));
  const status = h("div", { class: "s4-status" }, ...statusEls.map((el) => h("div", { class: "word" }, el)));

  root.append(art, vpnNode, ...labels, normalLabel, title, status);
  ctx.layer.append(root);

  const lengthA = tunnelA.getTotalLength();
  const lengthB = tunnelB.getTotalLength();
  const lengthAll = flow.getTotalLength();
  const lengthNormal = normal.getTotalLength();
  const breakPoint = tunnelA.getPointAtLength(lengthA * breakAt);
  const blockedPoint = normal.getPointAtLength(lengthNormal / 2);
  const rand = random(9);
  const packetOffsets = packets.map(() => rand());

  /** How much of the time downloading is flowing. */
  const flowing = (t: number) => (t < cue.drop ? seg(t, cue.toVpn + 0.7, cue.toVpn + 1.05) : t < cue.back + 0.2 ? Math.max(0, 1 - seg(t, cue.drop, cue.drop + 0.12)) : seg(t, cue.back + 0.2, cue.back + 0.5));
  const down = (t: number) => (t >= cue.drop && t < cue.back ? 1 : 0);

  const update = (t: number) => {
    const fade = 1 - seg(t, cue.zoom + 0.3, cue.fake);
    root.style.opacity = fade.toFixed(3);

    // The tunnel draws in; at the drop it snaps, at the break, and its ends pull back.
    const drawA = ease.inOutCubic(seg(t, cue.toVpn + 0.35, cue.toVpn + 0.85));
    const drawB = ease.inOutCubic(seg(t, cue.toVpn + 0.55, cue.toVpn + 1.05));
    const gap = (5 + 70 * ease.outExpo(seg(t, cue.drop, cue.drop + 0.35))) * (1 - ease.inOutCubic(seg(t, cue.back, cue.back + 0.28)));
    if (t < cue.drop) {
      tunnelA.style.strokeDasharray = `${lengthA} ${lengthA}`;
      tunnelA.style.strokeDashoffset = `${lengthA * (1 - drawA)}`;
    } else {
      const at = lengthA * breakAt;
      tunnelA.style.strokeDasharray = `${Math.max(0, at - gap)} ${gap * 2} ${lengthA}`;
      tunnelA.style.strokeDashoffset = "0";
    }
    tunnelB.style.strokeDasharray = `${lengthB} ${lengthB}`;
    tunnelB.style.strokeDashoffset = `${lengthB * (1 - drawB)}`;
    const isDown = down(t);
    for (const p of [tunnelA, tunnelB]) {
      p.setAttribute("stroke", isDown ? "url(#vpn-off)" : "url(#vpn-on)");
      p.style.opacity = isDown ? `${0.45 + 0.2 * Math.sin(t * 14)}` : "1";
    }

    // Downloads flowing in from the peers.
    const f = flowing(t);
    flow.style.opacity = (0.9 * f).toFixed(3);
    flow.style.strokeDashoffset = `${(t * 240).toFixed(1)}`;
    packets.forEach((packet, i) => {
      const along = ((packetOffsets[i] - t * 0.42) % 1 + 1) % 1;
      const point = flow.getPointAtLength(along * lengthAll);
      packet.setAttribute("cx", point.x.toFixed(1));
      packet.setAttribute("cy", point.y.toFixed(1));
      packet.style.opacity = (f * Math.min(1, along * 6, (1 - along) * 6)).toFixed(3);
    });

    // The normal connection, never used.
    const drawN = ease.inOutCubic(seg(t, cue.toVpn + 0.75, cue.toVpn + 1.35));
    normal.style.strokeDashoffset = `${(-t * 30).toFixed(1)}`;
    normal.style.opacity = drawN.toFixed(3);
    const pop = spring(t, cue.toVpn + 1.2, 3, 0.5);
    const throb = 1 + 0.35 * hit(t, cue.drop + 0.1, 0.18) * (t > cue.drop + 0.1 ? 1 : 0);
    blocked.setAttribute("transform", `translate(${blockedPoint.x} ${blockedPoint.y}) scale(${(pop * throb).toFixed(3)})`);
    put(normalLabel, { y: 10 * (1 - softOut(seg(t, cue.toVpn + 1.3, cue.toVpn + 1.85))), o: seg(t, cue.toVpn + 1.3, cue.toVpn + 1.6) });

    // The break, marked in amber.
    const b = spring(t, cue.drop, 3.4, 0.45) * (1 - seg(t, cue.back, cue.back + 0.2));
    breaks.setAttribute("transform", `translate(${breakPoint.x} ${breakPoint.y}) rotate(-18) scale(${Math.max(0, b).toFixed(3)})`);

    // The nodes.
    const vp = spring(t, cue.toVpn + 0.4, 2.6, 0.55);
    put(vpnNode, { s: vp, o: seg(t, cue.toVpn + 0.4, cue.toVpn + 0.52) });
    vpnNode.classList.toggle("is-down", !!isDown);
    lock.style.opacity = isDown ? "0" : "1";
    lockOpen.style.opacity = isDown ? "1" : "0";
    dots.forEach((dot, i) => {
      const s = spring(t, cue.toVpn + 0.55 + peerDots[i].delay, 2.8, 0.5);
      dot.style.transform = `scale(${s.toFixed(3)})`;
      dot.style.opacity = (seg(t, cue.toVpn + 0.55 + peerDots[i].delay, cue.toVpn + 0.65 + peerDots[i].delay) * (isDown ? 0.45 : 1)).toFixed(3);
    });
    lines.style.opacity = (seg(t, cue.toVpn + 0.75, cue.toVpn + 1.15) * (isDown ? 0.3 : 1)).toFixed(3);
    labels.forEach((label, i) => put(label, { y: 10 * (1 - softOut(seg(t, cue.toVpn + 0.55 + i * 0.1, cue.toVpn + 1.1 + i * 0.1))), o: seg(t, cue.toVpn + 0.55 + i * 0.1, cue.toVpn + 0.85 + i * 0.1) }));

    // The words.
    rise(wordsA, t, cue.warn, { stagger: 0.06, length: 0.75 });
    rise(wordsB, t, cue.drop + 0.06, { stagger: 0.06, length: 0.75 });
    sink([...wordsA, ...wordsB], t, cue.back - 0.1, { stagger: 0.02, length: 0.3 });
    statusEls.forEach((el, i) => {
      const s = states[i];
      const inP = softOut(seg(t, s.from, s.from + 0.5));
      const outP = ease.inCubic(seg(t, s.to - 0.02, s.to + 0.15));
      el.style.transform = `translate3d(0, ${((1 - inP) * 170 - outP * 170).toFixed(2)}%, 0)`;
    });
  };

  const hero = (t: number): Place => {
    // From scene 3's spot, down to the Mac's place in the diagram.
    const p = ease.inOutCubic(seg(t, cue.toVpn, cue.toVpn + 0.6));
    const [x, y] = cubic([orbHome.x, orbHome.y], [orbHome.x - 120, orbHome.y + 330], [mac.x + 420, mac.y + 150], [mac.x, mac.y], p);
    const d = Math.exp(Math.log(orbHome.d) + (Math.log(mac.d) - Math.log(orbHome.d)) * p);
    const jolt = (t > cue.drop ? hit(t, cue.drop, 0.12) : 0) * Math.sin(t * 90) * 8;
    return { x: x + jolt, y: y + Math.sin(t * 1.7) * 3 * p, d: d * (1 + 0.05 * Math.sin(Math.PI * seg(t, cue.back, cue.back + 0.4))) };
  };

  const scene: Scene = {
    from: cue.toVpn - 0.1,
    to: cue.fake + 0.05,
    root,
    update,
    effects(t) {
      // Sparks where the tunnel snaps.
      const p = seg(t, cue.drop, cue.drop + 0.6);
      if (p > 0 && p < 1) {
        const rand = random(3);
        for (let i = 0; i < 26; i++) {
          const a = rand() * Math.PI * 2;
          const v = 160 + rand() * 420;
          const q = ease.outCubic(p);
          const x = breakPoint.x + Math.cos(a) * v * q;
          const y = breakPoint.y + Math.sin(a) * v * q + 160 * p * p;
          fx.piece(ctx.back, x, y, Math.cos(a) * v * 0.04 * (1 - p), Math.sin(a) * v * 0.04 * (1 - p), 3 + rand() * 3, hex(rand() < 0.5 ? "#ff9926" : "#ffd27a"), 1 - p);
        }
        fx.glow(ctx.back, breakPoint.x, breakPoint.y, 160, hex("#ff9926"), 0.7 * (1 - p));
      }
      // While it's down, the VPN keeps trying, every other beat.
      for (let at = cue.drop + 2 * beat; at < cue.back - 0.2; at += 2 * beat) {
        const q = seg(t, at, at + 0.9);
        if (q > 0 && q < 1) fx.ring(ctx.back, vpn.x, vpn.y, 66 + 48 * ease.outCubic(q), 2 * (1 - q), hex("#ff9926"), 0.55 * (1 - q), 12);
      }
      // The connection coming back, along the tunnel.
      const r = seg(t, cue.back, cue.back + 0.45);
      if (r > 0 && r < 1) {
        const point = flow.getPointAtLength(ease.inOutCubic(r) * lengthAll);
        fx.glow(ctx.back, point.x, point.y, 70, hex("#9fe8ff"), 0.95 * (1 - r * 0.5));
        fx.ring(ctx.back, vpn.x, vpn.y, 66 + 120 * ease.outExpo(r), 2.5 * (1 - r), hex("#8fd0ff"), 0.8 * (1 - r), 14);
      }
      // Flash into the next scene.
      const flash = keys(t, [[cue.zoom + 0.25, 0], [cue.fake, 1, ease.inQuad]]);
      if (flash > 0) {
        ctx.front.fillStyle = `rgba(226, 236, 255, ${flash.toFixed(3)})`;
        ctx.front.fillRect(0, 0, 1920, 1080);
      }
    },
    camera(t) {
      // A jolt at the drop, then the push through the orb.
      const g = t >= cue.drop ? hit(t, cue.drop, 0.09) : 0;
      const rand = random(Math.floor(t * 60));
      const z = ease.inExpo(seg(t, cue.zoom, cue.fake));
      return {
        x: g * (rand() - 0.5) * 34,
        y: g * (rand() - 0.5) * 10,
        glitch: g > 0.02 ? g : 0,
        s: Math.exp(Math.log(18) * z),
        ox: mac.x,
        oy: mac.y,
      };
    },
  };
  return { scene, hero };
}
