// Draws the orb with WebGL, the same layers as the app's OrbView.swift: a
// turning globe of coloured light filled to a level, shaded as a sphere,
// under a highlight, in a ring of glass, with a glow behind.

import { toSRGB, type RGB } from "./palette";
import type { Appearance } from "./motion";

/** The globe's colours are sampled on this grid and blended smoothly, as the app's mesh gradient does. */
const N = 9;

const vertexSource = `#version 300 es
in vec2 a_position;
out vec2 v_uv;
void main() {
  v_uv = vec2(a_position.x * 0.5 + 0.5, 0.5 - a_position.y * 0.5);
  gl_Position = vec4(a_position, 0.0, 1.0);
}`;

const fragmentSource = `#version 300 es
precision highp float;
in vec2 v_uv;
out vec4 outColor;

uniform float u_pad;      // space around the orb for its glow, in diameters
uniform float u_px;       // one device pixel, in diameters
uniform float u_pt;       // one CSS pixel, in diameters
uniform vec3 u_grid[${N * N}];
uniform vec3 u_ambient;   // ambient[0]
uniform vec3 u_veil;      // veils[0]
uniform vec3 u_glow;
uniform float u_level;
uniform float u_phase;
uniform float u_amp;
uniform float u_sat;
uniform float u_glowAlpha;
uniform float u_glowScale;
uniform float u_line;
uniform float u_glass;

const float INSET = 0.045;
const float INNER = 0.91;
const vec2 C = vec2(0.5);
const float PI = 3.14159265;

// Premultiplied colours throughout.
vec4 over(vec4 top, vec4 under) { return top + under * (1.0 - top.a); }
vec4 lighter(vec4 top, vec4 under) { return vec4(min(under.rgb + top.rgb, 1.0), min(under.a + top.a, 1.0)); }
// SwiftUI blends these layers as sRGB, so this does too.
vec4 premul(vec3 c, float a) { return vec4(c * a, a); }

float disc(vec2 p, vec2 c, float r, float soft) {
  return clamp((r - length(p - c)) / max(soft, u_px) + 0.5, 0.0, 1.0);
}

vec3 saturate3(vec3 c, float s) {
  float l = dot(c, vec3(0.2126, 0.7152, 0.0722));
  return clamp(mix(vec3(l), c, s), 0.0, 1.0);
}

// Catmull-Rom weights, for the mesh gradient's smooth colours.
vec4 cr(float t) {
  float t2 = t * t, t3 = t2 * t;
  return 0.5 * vec4(-t3 + 2.0 * t2 - t, 3.0 * t3 - 5.0 * t2 + 2.0, -3.0 * t3 + 4.0 * t2 + t, t3 - t2);
}


vec3 grid(int x, int y) {
  x = clamp(x, 0, ${N - 1}); y = clamp(y, 0, ${N - 1});
  return u_grid[y * ${N} + x];
}

vec3 globe(vec2 p) {
  vec2 g = clamp(p, 0.0, 1.0) * float(${N - 1});
  ivec2 i = ivec2(min(floor(g), vec2(${N - 2})));
  vec2 f = g - vec2(i);
  vec4 wx = cr(f.x), wy = cr(f.y);
  vec3 c = vec3(0.0);
  for (int y = 0; y < 4; y++) {
    vec3 row = vec3(0.0);
    for (int x = 0; x < 4; x++) row += grid(i.x + x - 1, i.y + y - 1) * wx[x];
    c += row * wy[y];
  }
  return saturate3(c, 1.2);
}

float wave(float u) {
  return sin(u * PI * 1.9 + u_phase * 1.4) * 0.65 + sin(u * PI * 3.7 - u_phase * 0.95) * 0.35;
}
float waveSlope(float u) {
  return cos(u * PI * 1.9 + u_phase * 1.4) * 0.65 * PI * 1.9 + cos(u * PI * 3.7 - u_phase * 0.95) * 0.35 * PI * 3.7;
}

// A crescent hugging the inside of the inner circle, thickest towards angle a.
float crescent(vec2 p, float thickness, float a, float soft) {
  float r = INNER * 0.5;
  float shift = INNER * thickness;
  vec2 c2 = C - vec2(cos(a), sin(a)) * shift;
  return disc(p, C, r, soft) * (1.0 - disc(p, c2, r - INNER * 0.004, soft));
}

void main() {
  vec2 p = -u_pad + v_uv * (1.0 + 2.0 * u_pad);
  float r = length(p - C);
  vec2 q = (p - INSET) / INNER;        // position in the inner circle's square

  // The glow behind the glass: a soft disc.
  float gr = 0.5 * u_glowScale;
  float sigma = 0.06;
  float x = (r - gr) / (sigma * 1.41421);
  float t = 1.0 / (1.0 + 0.3275911 * abs(x));
  float erfAbs = 1.0 - (((((1.061405429 * t - 1.453152027) * t) + 1.421413741) * t - 0.284496736) * t + 0.254829592) * t * exp(-x * x);
  float erfc = 1.0 - sign(x) * erfAbs;
  vec4 col = premul(u_glow, u_glowAlpha * 0.5 * erfc);

  // The glass: a frosted disc, lit along its rim.
  float outer = disc(p, C, 0.5, u_px);
  if (u_glass > 0.5) {
    vec3 tint = mix(vec3(1.0), u_glow, 0.72);
    col = over(premul(tint, 0.34 * outer), col);
  }

  // A little colour in the glass, so an empty orb still reads as one.
  float inside = disc(p, C, INNER * 0.5, u_px);
  {
    float d = length(q - vec2(0.4, 0.35)) / 0.62;
    float s = clamp(d, 0.0, 1.0);
    vec3 c = mix(u_veil, u_ambient, s);
    float a = mix(0.24, 0.10, s);
    col = over(premul(saturate3(c, u_sat), a * inside), col);
  }

  // The light: the globe shaded as a sphere, filled to a level.
  vec4 light = premul(globe(p), 1.0);
  {
    float d = length(q - vec2(0.45, 0.4)) / 0.56;
    float a = 0.28 * clamp((d - 0.55) / 0.45, 0.0, 1.0);
    light = over(vec4(0.0, 0.0, 0.0, a), light);
  }
  {
    float d = clamp(length(q - vec2(0.32, 0.28)) / 0.5, 0.0, 1.0);
    light = lighter(premul(u_veil, 0.55 * (1.0 - d)), light);
  }
  {
    vec2 e = q - vec2(0.5 - 0.12, 0.5 - 0.26);
    float inEllipse = clamp((1.0 - length(e / vec2(0.31, 0.2))) / (u_px * 6.0) + 0.5, 0.0, 1.0);
    float d = clamp(length(e) / 0.3, 0.0, 1.0);
    light = lighter(premul(vec3(1.0), 0.22 * (1.0 - d) * inEllipse), light);
  }
  {
    float shape = crescent(p, 0.05, PI * 0.5, 0.02);
    float g = clamp((1.0 - q.y) / 0.5, 0.0, 1.0);
    light = lighter(premul(vec3(1.0), 0.3 * (1.0 - g) * shape), light);
  }

  float top = 1.0 - u_level * (1.0 + 2.0 * u_amp) + u_amp;
  float surface = top + u_amp * wave(p.x);
  float below = clamp((p.y - surface) / u_px + 0.5, 0.0, 1.0);
  light *= below;

  if (u_line > 0.5) {
    float slope = u_amp * waveSlope(p.x);
    float dist = abs(p.y - surface) / sqrt(1.0 + slope * slope);
    float width = max(0.5 * u_pt, 0.007);
    float a = clamp((width * 0.5 - dist) / max(u_px, 0.004) + 0.5, 0.0, 1.0);
    light = over(premul(vec3(1.0), 0.55 * a), light);
  }
  if (light.a > 0.0) light.rgb = saturate3(light.rgb / light.a, u_sat) * light.a;
  col = over(light * inside, col);

  // A highlight across the light, so it sits under the same glass.
  {
    float shape = crescent(p, 0.028, -PI * 2.0 / 3.0, 0.006);
    float g = clamp(((q.x + q.y) * 0.5) / 0.4, 0.0, 1.0);
    col = over(premul(vec3(1.0), 0.6 * (1.0 - g) * shape), col);
  }

  // The glass's rim: a thin light edge all round, brightest where light
  // catches it at the top left and passes through at the bottom.
  if (u_glass > 0.5) {
    vec2 n = normalize(p - C + 1e-6);
    float edge = clamp(1.0 - abs(r - (0.5 - 0.0045)) / max(0.0045, u_px * 1.5), 0.0, 1.0);
    float key = pow(max(0.0, dot(n, normalize(vec2(-0.55, -0.85)))), 2.0);
    float under = pow(max(0.0, dot(n, vec2(0.0, 1.0))), 2.0);
    col = over(premul(vec3(1.0), edge * (0.16 + 0.3 * key + 0.2 * under)), col);
  }

  outColor = col;
}`;

export interface RenderOptions {
  /** Draw the glass ring; off only for comparing against the app's renders. */
  glass?: boolean;
}

export class OrbRenderer {
  readonly canvas: HTMLCanvasElement;
  private gl: WebGL2RenderingContext;
  private program!: WebGLProgram;
  private parallel: { COMPLETION_STATUS_KHR: number } | null;
  private linked = false;
  private uniforms: Record<string, WebGLUniformLocation | null> = {};
  private grid = new Float32Array(N * N * 3);
  /** Space around the orb for its glow, in diameters. */
  readonly pad: number;

  static supported(): boolean {
    try {
      return !!document.createElement("canvas").getContext("webgl2");
    } catch {
      return false;
    }
  }

  constructor(canvas: HTMLCanvasElement, pad = 0.3) {
    this.canvas = canvas;
    this.pad = pad;
    const gl = canvas.getContext("webgl2", { premultipliedAlpha: true, alpha: true, antialias: false });
    if (!gl) throw new Error("WebGL2 is not available");
    this.gl = gl;
    // Compiling takes a moment; with this extension it happens off the main
    // thread, so the page stays responsive while the orb gets ready.
    this.parallel = gl.getExtension("KHR_parallel_shader_compile");
    this.compile();
  }

  /** Whether the shaders are ready; checking doesn't wait for them. */
  get ready(): boolean {
    if (this.linked) return true;
    const gl = this.gl;
    if (this.parallel && !gl.getProgramParameter(this.program, this.parallel.COMPLETION_STATUS_KHR)) return false;
    if (!gl.getProgramParameter(this.program, gl.LINK_STATUS)) throw new Error(gl.getProgramInfoLog(this.program) ?? "program");
    gl.useProgram(this.program);
    const buffer = gl.createBuffer();
    gl.bindBuffer(gl.ARRAY_BUFFER, buffer);
    gl.bufferData(gl.ARRAY_BUFFER, new Float32Array([-1, -1, 1, -1, -1, 1, 1, 1]), gl.STATIC_DRAW);
    const location = gl.getAttribLocation(this.program, "a_position");
    gl.enableVertexAttribArray(location);
    gl.vertexAttribPointer(location, 2, gl.FLOAT, false, 0, 0);
    for (const name of ["u_pad", "u_px", "u_pt", "u_grid", "u_ambient", "u_veil", "u_glow", "u_level", "u_phase",
      "u_amp", "u_sat", "u_glowAlpha", "u_glowScale", "u_line", "u_glass"]) {
      this.uniforms[name] = gl.getUniformLocation(this.program, name);
    }
    this.linked = true;
    return true;
  }

  private compile() {
    const gl = this.gl;
    const shader = (type: number, source: string) => {
      const s = gl.createShader(type)!;
      gl.shaderSource(s, source);
      gl.compileShader(s);
      return s;
    };
    this.program = gl.createProgram()!;
    gl.attachShader(this.program, shader(gl.VERTEX_SHADER, vertexSource));
    gl.attachShader(this.program, shader(gl.FRAGMENT_SHADER, fragmentSource));
    gl.linkProgram(this.program);
  }

  /** Sizes the drawing buffer to the canvas's size on screen; returns the orb's diameter in CSS pixels. */
  resize(): number {
    const ratio = Math.min(window.devicePixelRatio || 1, 2);
    const width = this.canvas.clientWidth;
    const pixels = Math.max(1, Math.round(width * ratio));
    if (this.canvas.width !== pixels || this.canvas.height !== pixels) {
      this.canvas.width = pixels;
      this.canvas.height = pixels;
    }
    this.gl.viewport(0, 0, pixels, pixels);
    return width / (1 + 2 * this.pad);
  }

  draw(a: Appearance, options: RenderOptions = {}) {
    if (!this.ready) return;
    const gl = this.gl;
    const u = this.uniforms;
    const span = 1 + 2 * this.pad;
    const diameter = this.canvas.clientWidth / span;
    this.fillGrid(a);
    const srgb = (c: RGB) => c.map(toSRGB) as RGB;
    const [, ambient0, , , veil0, , , glow] = a.palette;
    const amp = 0.022 * (0.5 + 0.5 * a.energy) * Math.min(1, Math.sin(Math.PI * a.level) * 2.5);

    gl.uniform1f(u.u_pad, this.pad);
    gl.uniform1f(u.u_px, span / this.canvas.width);
    gl.uniform1f(u.u_pt, 1 / Math.max(diameter, 1));
    gl.uniform3fv(u.u_grid, this.grid);
    gl.uniform3fv(u.u_ambient, srgb(ambient0));
    gl.uniform3fv(u.u_veil, srgb(veil0));
    gl.uniform3fv(u.u_glow, srgb(glow));
    gl.uniform1f(u.u_level, a.level);
    gl.uniform1f(u.u_phase, a.phase);
    gl.uniform1f(u.u_amp, amp);
    gl.uniform1f(u.u_sat, a.saturation);
    gl.uniform1f(u.u_glowAlpha, 0.12 + 0.25 * a.energy * a.level + 0.3 * a.bloom);
    gl.uniform1f(u.u_glowScale, 0.86 + 0.08 * a.bloom);
    gl.uniform1f(u.u_line, a.level > 0.005 && a.level < 0.995 ? 1 : 0);
    gl.uniform1f(u.u_glass, options.glass === false ? 0 : 1);
    gl.clearColor(0, 0, 0, 0);
    gl.clear(gl.COLOR_BUFFER_BIT);
    gl.drawArrays(gl.TRIANGLE_STRIP, 0, 4);
  }

  /**
   * Pools of colour on a slowly turning globe, sampled on a grid, as the
   * app's OrbView.globe does, mixing the colours as sRGB.
   */
  private fillGrid(a: Appearance) {
    const t = a.phase;
    const p = a.palette.map((c) => c.map(toSRGB)) as Appearance["palette"];
    const base = p[1];
    const pools: [number, number, number, RGB][] = [
      [0.0, 0.5, 0.11, p[4]], [0.8, -0.3, 0.14, p[5]], [1.6, 0.25, 0.15, p[0]],
      [2.4, -0.45, 0.11, p[6]], [3.1, 0.4, 0.14, p[2]], [3.9, -0.1, 0.1, p[4]],
      [4.7, 0.55, 0.14, p[5]], [5.5, -0.35, 0.15, p[3]],
    ];
    const centers = pools.map(([longitude, latitude], k) => {
      const lon = longitude + 0.25 * Math.sin(t * 0.31 + k * 1.7);
      const lat = latitude + 0.18 * Math.sin(t * 0.27 + k * 2.3);
      return [Math.cos(lat) * Math.sin(lon), Math.sin(lat), Math.cos(lat) * Math.cos(lon)];
    });
    let i = 0;
    for (let row = 0; row < N; row++) {
      for (let column = 0; column < N; column++) {
        const x = column / (N - 1), y = row / (N - 1);
        let dx = (x - 0.5) * 2, dy = (0.5 - y) * 2;
        const length = Math.hypot(dx, dy);
        if (length > 1) { dx /= length; dy /= length; }
        const cosLatitude = Math.sqrt(Math.max(0, 1 - dy * dy));
        const sinLongitude = cosLatitude > 1e-6 ? Math.min(1, Math.max(-1, dx / cosLatitude)) : 0;
        const longitude = Math.asin(sinLongitude) - a.spin;
        const point = [cosLatitude * Math.sin(longitude), dy, cosLatitude * Math.cos(longitude)];
        let r = base[0] * 0.12, g = base[1] * 0.12, b = base[2] * 0.12, total = 0.12;
        for (let k = 0; k < pools.length; k++) {
          const c = centers[k];
          const weight = Math.exp((point[0] * c[0] + point[1] * c[1] + point[2] * c[2] - 1) / pools[k][2]);
          const color = pools[k][3];
          r += color[0] * weight; g += color[1] * weight; b += color[2] * weight;
          total += weight;
        }
        this.grid[i++] = r / total;
        this.grid[i++] = g / total;
        this.grid[i++] = b / total;
      }
    }
  }
}
