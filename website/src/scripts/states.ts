// The orb's states, as tabs: choosing one sets the live orb, the stage's
// light, the status line and the picture beside it. They take turns on
// their own while the section is on screen, unless you'd rather they didn't.

import type { Orb, OrbState } from "./orb";

// The tabs work from the start; the live orb joins in once it's ready, which
// is only as it nears the screen.
export function playStates(section: HTMLElement, orbElement: HTMLElement & { orb?: Orb }) {
  const live = () => orbElement.orb;
  const tabs = [...section.querySelectorAll<HTMLButtonElement>("[role=tab]")];
  const stage = section.querySelector<HTMLElement>("[data-stage]")!;
  const status = section.querySelector<HTMLElement>("[data-status]")!;
  const meter = section.querySelector<HTMLElement>("[data-meter]");
  const meterText = section.querySelector<HTMLElement>("[data-meter-text]");
  const still = matchMedia("(prefers-reduced-motion: reduce)");
  let current = -1;
  let seedingTimer = 0;
  let frame = 0;

  const bar = (tab: HTMLElement) => tab.querySelector<HTMLElement>("[data-bar]")!;

  // While downloading, the orb fills as the tab's own timer runs.
  const follow = () => {
    const tab = tabs[current];
    const timer = bar(tab).getAnimations()[0];
    const through = timer ? Number(timer.currentTime ?? 0) / Number(timer.effect?.getTiming().duration ?? 1) : 0.6;
    const progress = 0.12 + 0.8 * Math.min(1, Math.max(0, through));
    live()?.setState({ kind: "downloading", progress, energy: 0.9 });
    status.textContent = `Downloading · ${Math.round(progress * 100)}%`;
    meter?.style.setProperty("--progress", progress.toFixed(3));
    if (meterText) meterText.textContent = `${(6.48 * progress).toFixed(2)} GB of 6.48 GB · ↓ 2.3 MB/s`;
    // Without a running timer (as with reduced motion) it holds where it is.
    if (timer) frame = requestAnimationFrame(follow);
  };

  const select = (index: number, focus = false) => {
    if (index === current) return;
    current = index;
    clearTimeout(seedingTimer);
    cancelAnimationFrame(frame);
    tabs.forEach((tab, i) => {
      const on = i === index;
      tab.setAttribute("aria-selected", String(on));
      tab.tabIndex = on ? 0 : -1;
    });
    const tab = tabs[index];
    if (focus) tab.focus();
    const state = JSON.parse(tab.dataset.state!) as OrbState;
    stage.dataset.show = tab.dataset.key;
    stage.style.setProperty("--tint", tab.dataset.tint!);
    status.parentElement!.style.setProperty("--dot", tab.dataset.tint!);
    if (state.kind === "downloading") return follow();
    live()?.setState(state);
    status.textContent = tab.dataset.statusText!;
    // Finishing flashes the glow; then it goes on sharing, breathing gently.
    if (state.kind === "finished") {
      seedingTimer = window.setTimeout(() => {
        live()?.setState({ kind: "seeding" });
        status.textContent = "Finished · sharing";
      }, 2400);
    }
  };

  tabs.forEach((tab, index) => {
    tab.addEventListener("click", () => select(index));
    tab.addEventListener("keydown", (event) => {
      const step = { ArrowDown: 1, ArrowRight: 1, ArrowUp: -1, ArrowLeft: -1 }[event.key];
      if (event.key === "Home") return void (event.preventDefault(), select(0, true));
      if (event.key === "End") return void (event.preventDefault(), select(tabs.length - 1, true));
      if (!step) return;
      event.preventDefault();
      select((index + step + tabs.length) % tabs.length, true);
    });
    // When a tab's timer runs out, the next one takes over.
    bar(tab).addEventListener("animationend", () => {
      if (index === current && !still.matches) select((index + 1) % tabs.length);
    });
  });

  // The timers only run while the section is on screen, and wait while
  // you're pointing at or reading a tab.
  const pause = (why: string, on: boolean) => {
    const reasons = new Set((section.dataset.paused ?? "").split(" ").filter(Boolean));
    if (on) reasons.add(why); else reasons.delete(why);
    if (reasons.size) section.dataset.paused = [...reasons].join(" ");
    else delete section.dataset.paused;
  };
  new IntersectionObserver(([entry]) => pause("away", !entry.isIntersecting), { threshold: 0.35 }).observe(section);
  const list = section.querySelector<HTMLElement>("[role=tablist]")!;
  list.addEventListener("pointerenter", () => pause("hover", true));
  list.addEventListener("pointerleave", () => pause("hover", false));
  list.addEventListener("focusin", () => pause("focus", true));
  list.addEventListener("focusout", () => pause("focus", false));

  orbElement.addEventListener("orb:ready", () => {
    const index = current;
    current = -1;
    select(index);
  }, { once: true });

  pause("away", true);
  select(0);
}
