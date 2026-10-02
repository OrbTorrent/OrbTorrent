// The live orb: animates a canvas from a state, the way the app's LiveOrb does.
// It pauses while off screen or in a background tab, and holds still for
// people who ask for reduced motion.

import { OrbMotion, type OrbState } from "./motion";
import { OrbRenderer } from "./renderer";

export type { OrbState } from "./motion";

export interface OrbOptions {
  state?: OrbState;
  /** How fast the globe turns, as a multiple of its usual pace. */
  turnSpeed?: number;
  seed?: number;
}

const reducedMotion = window.matchMedia("(prefers-reduced-motion: reduce)");

export class Orb {
  private renderer: OrbRenderer;
  private motion: OrbMotion;
  private state: OrbState;
  private turnSpeed: number;
  private frame = 0;
  private last = 0;
  private visible = false;
  private observer: IntersectionObserver;
  private resizer: ResizeObserver;

  static supported = OrbRenderer.supported;

  constructor(canvas: HTMLCanvasElement, options: OrbOptions = {}) {
    this.renderer = new OrbRenderer(canvas);
    this.motion = new OrbMotion(options.seed);
    this.state = options.state ?? { kind: "idle" };
    this.turnSpeed = options.turnSpeed ?? 1;
    this.observer = new IntersectionObserver(([entry]) => {
      this.visible = entry.isIntersecting;
      this.schedule();
    }, { rootMargin: "100px" });
    this.observer.observe(canvas);
    this.resizer = new ResizeObserver(() => {
      this.renderer.resize();
      if (this.isStill) this.drawStill();
    });
    this.resizer.observe(canvas);
    document.addEventListener("visibilitychange", this.schedule);
    reducedMotion.addEventListener("change", this.schedule);
    const start = () => {
      if (!this.renderer.ready) return void requestAnimationFrame(start);
      this.renderer.resize();
      this.drawStill();
      canvas.dataset.ready = "";
      this.started = true;
      this.schedule();
    };
    start();
  }

  private started = false;

  setState(state: OrbState) {
    this.state = state;
    if (this.isStill) this.drawStill();
  }

  setTurnSpeed(speed: number) {
    this.turnSpeed = speed;
  }

  destroy() {
    cancelAnimationFrame(this.frame);
    this.observer.disconnect();
    this.resizer.disconnect();
    document.removeEventListener("visibilitychange", this.schedule);
    reducedMotion.removeEventListener("change", this.schedule);
  }

  private get isStill() {
    return reducedMotion.matches;
  }

  private drawStill() {
    this.renderer.draw(this.isStill ? this.motion.still(this.state) : this.motion.advance(0, this.state, this.turnSpeed));
  }

  private schedule = () => {
    if (!this.started) return;
    cancelAnimationFrame(this.frame);
    this.frame = 0;
    if (this.isStill) {
      this.drawStill();
      return;
    }
    if (this.visible && !document.hidden) {
      this.last = performance.now();
      this.frame = requestAnimationFrame(this.tick);
    }
  };

  private tick = (now: number) => {
    const dt = (now - this.last) / 1000;
    this.last = now;
    this.renderer.draw(this.motion.advance(dt, this.state, this.turnSpeed));
    this.frame = requestAnimationFrame(this.tick);
  };
}
