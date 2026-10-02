import { spawnSync } from "node:child_process";
import { cpSync, existsSync, rmSync, writeFileSync } from "node:fs";
import { builtinModules, createRequire } from "node:module";
import { join, relative } from "node:path";
import * as esbuild from "esbuild";
import { CommandError } from "./output.js";
import { InvalidManifest, Manifest, builtManifest, environmentDeclarations, readManifest } from "./manifest.js";
import { sdkVersion } from "./paths.js";

export interface BuildResult {
  manifest: Manifest;
  folder: string;
  dist: string;
  /** Hook name → bundled file. */
  hooks: Record<string, string>;
  verify?: string;
  warnings: string[];
}

const sourceExtensions = [".ts", ".tsx", ".js", ".jsx"];

/** The file in src that an entry point's name maps to. */
export function entryFile(folder: string, name: string): string | undefined {
  return sourceExtensions.map((extension) => join(folder, "src", name + extension)).find(existsSync);
}

/** Reads package.json, reporting its problems the way `orb` does. */
export function loadManifest(folder: string): Manifest {
  try {
    return readManifest(folder);
  } catch (error) {
    if (error instanceof InvalidManifest) throw new CommandError("package.json isn't valid.", error.problems);
    throw error;
  }
}

/** Checks, bundles and writes an extension to dist/, the way OrbTorrent loads it. */
export async function build(folder: string, options: { typeCheck?: boolean } = {}): Promise<BuildResult> {
  const manifest = loadManifest(folder);
  const warnings: string[] = [];

  const entries: { in: string; out: string }[] = [];
  const missing: string[] = [];
  for (const hook of manifest.hooks) {
    const file = entryFile(folder, hook.name);
    if (file) entries.push({ in: file, out: `hooks/${hook.name}` });
    else missing.push(`The hook “${hook.name}” needs src/${hook.name}.ts.`);
  }
  if (manifest.verify) {
    const file = entryFile(folder, manifest.verify);
    if (file) entries.push({ in: file, out: "verify" });
    else missing.push(`“verify” names src/${manifest.verify}.ts, which doesn't exist.`);
  }
  if (missing.length > 0) throw new CommandError("Some entry points are missing.", missing);
  if (manifest.icon && !existsSync(join(folder, "assets", manifest.icon))) {
    warnings.push(`The icon assets/${manifest.icon} doesn't exist, so OrbTorrent shows a plain one.`);
  }

  writeFileSync(join(folder, "orb-env.d.ts"), environmentDeclarations(manifest));

  // Bundling first gives the clearer message for a Node.js import; the type
  // check would suggest installing Node's types, which can't work here.
  const dist = join(folder, "dist");
  rmSync(dist, { recursive: true, force: true });
  try {
    await esbuild.build({
      entryPoints: entries,
      outdir: dist,
      bundle: true,
      format: "iife",
      globalName: "__orbExtension",
      platform: "neutral",
      target: "es2022",
      mainFields: ["module", "main"],
      charset: "utf8",
      define: { "process.env.NODE_ENV": '"production"' },
      logLevel: "silent",
      plugins: [noNodeModules],
    });
  } catch (error) {
    const failure = error as esbuild.BuildFailure;
    if (!Array.isArray(failure.errors)) throw error;
    throw new CommandError("The extension couldn't be bundled.", failure.errors.map((message) => {
      const place = message.location ? `${relative(folder, message.location.file) || message.location.file}:${message.location.line}:${message.location.column + 1}: ` : "";
      return place + message.text;
    }));
  }

  if (options.typeCheck !== false && existsSync(join(folder, "tsconfig.json"))) {
    try {
      typeCheck(folder);
    } catch (error) {
      rmSync(dist, { recursive: true, force: true });
      throw error;
    }
  }

  writeFileSync(join(dist, "package.json"), JSON.stringify(builtManifest(manifest, sdkVersion), null, 2) + "\n");
  for (const name of ["assets", "help.md", "README.md", "CHANGELOG.md"]) {
    const source = join(folder, name);
    if (existsSync(source)) cpSync(source, join(dist, name), { recursive: true });
  }

  const hooks = Object.fromEntries(manifest.hooks.map((hook) => [hook.name, join(dist, "hooks", `${hook.name}.js`)]));
  return { manifest, folder, dist, hooks, verify: manifest.verify ? join(dist, "verify.js") : undefined, warnings };
}

/** Runs the TypeScript compiler this package ships, reporting its errors. */
function typeCheck(folder: string): void {
  const tsc = createRequire(import.meta.url).resolve("typescript/bin/tsc");
  const result = spawnSync(process.execPath, [tsc, "--noEmit", "--pretty", "false", "-p", join(folder, "tsconfig.json")], {
    cwd: folder,
    encoding: "utf8",
  });
  if (result.status === 0) return;
  const lines = `${result.stdout}${result.stderr}`.split("\n").map((line) => line.trim()).filter(Boolean);
  throw new CommandError("TypeScript found problems.", lines.map((line) => line.replace(/^(.+?)\((\d+),(\d+)\): /, "$1:$2:$3: ")));
}

const nodeModuleNames = new Set(builtinModules.map((name) => name.replace(/^node:/, "")));

function nodeHint(module: string): string {
  switch (module) {
    case "fs":
    case "fs/promises":
    case "path":
      return "To read a download's files, use files.sha256 or files.formData from @orbtorrent/api, and to add one next to them, files.save.";
    case "http":
    case "https":
    case "net":
    case "dns":
    case "tls":
      return "Use fetch from @orbtorrent/api.";
    case "crypto":
      return "For ids use crypto.randomUUID(); for a file's fingerprint use files.sha256 from @orbtorrent/api.";
    case "buffer":
      return "Use Uint8Array, TextEncoder and TextDecoder.";
    case "child_process":
    case "worker_threads":
      return "Extensions can't start programs. OrbTorrent can run one of the user's own when a download finishes: Settings › Downloads.";
    default:
      return "Use the functions in @orbtorrent/api instead.";
  }
}

/** Refuses Node.js modules: extensions run in OrbTorrent's JavaScript engine. */
const noNodeModules: esbuild.Plugin = {
  name: "orbtorrent-no-node-modules",
  setup(build) {
    build.onResolve({ filter: /^[^./]/ }, (args) => {
      const module = args.path.replace(/^node:/, "");
      const isNode = args.path.startsWith("node:") || nodeModuleNames.has(module) || nodeModuleNames.has(module.split("/")[0]);
      if (!isNode) return undefined;
      return {
        errors: [{ text: `“${args.path}” is a Node.js module, and extensions don't run in Node.js. ${nodeHint(module)}` }],
      };
    });
  },
};
