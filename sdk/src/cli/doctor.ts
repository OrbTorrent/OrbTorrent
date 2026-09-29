import { spawnSync } from "node:child_process";
import { existsSync, readFileSync } from "node:fs";
import { join } from "node:path";
import { AppConnection, appName, bundleIdentifier, Message } from "./connection.js";
import { printJSON, style } from "./output.js";
import { sdkVersion } from "./paths.js";

/** One thing `orb doctor` checked. `ok` is null for information that needs nothing done. */
export interface Check {
  name: string;
  ok: boolean | null;
  message: string;
  /** What to do about it, and who: some steps only the user can take in OrbTorrent. */
  fix?: string;
}

const switchPlace = `in ${appName}: Extensions, at the bottom of the sidebar, then the Develop tab`;

/** Whether an extension built with API `extension` can run in an OrbTorrent that supports `app`. */
export function apiSupports(app: string, extension: string): boolean {
  const [appMajor, appMinor] = app.split(".").map(Number);
  const [major, minor] = extension.split(".").map(Number);
  return major === appMajor && minor <= appMinor;
}

function nodeIsRecent(version: string): boolean {
  const [major, minor] = version.split(".").map(Number);
  return major > 22 || (major === 22 && minor >= 13);
}

function readManifest(folder: string): { name: string; title?: string } | undefined {
  try {
    const manifest = JSON.parse(readFileSync(join(folder, "package.json"), "utf8"));
    return typeof manifest.name === "string" && Array.isArray(manifest.hooks) ? manifest : undefined;
  } catch {
    return undefined;
  }
}

/** Where the app is, by its bundle identifier, using Spotlight. */
function findApp(): string | undefined {
  const found = spawnSync("/usr/bin/mdfind", [`kMDItemCFBundleIdentifier == '${bundleIdentifier}'`], { encoding: "utf8", timeout: 3000 });
  const path = found.status === 0 ? found.stdout.split("\n").find((line) => line.endsWith(".app")) : undefined;
  if (path) return path;
  return [`/Applications/${appName}.app`, join(process.env.HOME ?? "", "Applications", `${appName}.app`)].find((candidate) => existsSync(candidate));
}

function isOpen(): boolean {
  return spawnSync("/usr/bin/pgrep", ["-x", appName]).status === 0;
}

/** Checks Node.js, OrbTorrent and the extension in `folder`, and says what to fix. */
export async function doctor(folder: string): Promise<Check[]> {
  const checks: Check[] = [];
  const node = process.versions.node;
  checks.push(nodeIsRecent(node)
    ? { name: "node", ok: true, message: `Node.js ${node}` }
    : { name: "node", ok: false, message: `Node.js ${node} is too old.`, fix: "Install Node.js 22.13 or later, from nodejs.org or with `brew install node`." });

  const manifest = readManifest(folder);
  const dist = join(folder, "dist");
  const built = manifest !== undefined && existsSync(join(dist, "package.json"));
  if (manifest) {
    checks.push({ name: "extension", ok: true, message: `${manifest.title ?? manifest.name} (${manifest.name}), with @orbtorrent/api ${sdkVersion}` });
    checks.push(built
      ? { name: "built", ok: true, message: "Built into dist/" }
      : { name: "built", ok: false, message: "Not built yet.", fix: "Run `npx orb build`." });
  } else {
    checks.push({ name: "extension", ok: null, message: "Not in an extension's folder, so only OrbTorrent is checked." });
  }

  let connection: AppConnection | undefined;
  try {
    connection = await AppConnection.open();
  } catch {
    connection = undefined;
  }
  try {
    if (connection) {
      const version = connection.app.version ? ` ${connection.app.version}` : "";
      checks.push({ name: "app", ok: true, message: `${appName}${version} is open and allows development extensions.` });
    } else if (isOpen()) {
      checks.push({
        name: "app", ok: false, message: `${appName} is open, but doesn't allow development extensions.`,
        fix: `Ask the user to turn on “Allow development extensions” ${switchPlace}. Only the user can. If the switch at the top of the Installed tab is off, extensions are off altogether, and that needs turning on first.`,
      });
    } else {
      const path = findApp();
      checks.push(path
        ? {
          name: "app", ok: false, message: `${appName} isn't open.`,
          fix: `Open it with \`open -b ${bundleIdentifier}\`, then ask the user to turn on “Allow development extensions” ${switchPlace}, if it's off.`,
        }
        : { name: "app", ok: false, message: `${appName} isn't installed.`, fix: "Ask the user to download OrbTorrent from orbtorrent.com and open it." });
    }

    if (connection && manifest) {
      const api = String(connection.app.api ?? "1.0.0").split(".").slice(0, 2).join(".");
      checks.push(apiSupports(api, sdkVersion)
        ? { name: "api", ok: true, message: `${appName} supports extension API ${api}, which this extension needs.` }
        : {
          name: "api", ok: false, message: `This extension uses @orbtorrent/api ${sdkVersion}, but ${appName} supports extension API ${api}.`,
          fix: `Ask the user to update ${appName} (${appName} → Check for Updates…), or use @orbtorrent/api ${api}.x.`,
        });

      let status: Message | undefined;
      try {
        status = await connection.request({ type: "status", name: manifest.name, ...(built && { path: dist }) }, ["status"]);
      } catch {
        checks.push({ name: "status", ok: null, message: `This ${appName} can't say whether the folder is allowed or the extension installed. Updating it can.` });
      }
      if (status) {
        if (built) {
          checks.push(status.allowed
            ? { name: "allowed", ok: true, message: `The user has allowed this folder in ${appName}.` }
            : { name: "allowed", ok: null, message: `The first \`orb run\` or \`orb dev\` asks the user to allow this folder in ${appName}. Tell them to expect it.` });
        }
        const active = status.active as { source: string; version: string; on: boolean } | undefined;
        const installed = status.installed as { version: string } | undefined;
        const state = active ? (active.on ? "on" : "turned off") : "";
        if (installed) {
          const standIn = active?.source === "development" ? `, though ${appName} runs the development copy while it's loaded`
            : state ? `, ${state}` : "";
          const version = installed.version ? `, version ${installed.version}` : "";
          checks.push({ name: "installed", ok: null, message: `Installed in ${appName}${version}${standIn}.` });
        } else if (active?.source === "development") {
          checks.push({ name: "installed", ok: null, message: `Loaded for development, ${state}. \`npx orb install\` installs it for good.` });
        } else {
          checks.push({ name: "installed", ok: null, message: "Not installed yet. `npx orb install` asks the user to install it." });
        }
      }
    }
  } finally {
    connection?.close();
  }
  return checks;
}

export async function doctorCommand(folder: string, json: boolean): Promise<boolean> {
  const checks = await doctor(folder);
  const ok = checks.every((check) => check.ok !== false);
  if (json) {
    printJSON({ ok, checks });
    return ok;
  }
  for (const check of checks) {
    const mark = check.ok === true ? style.green("✓") : check.ok === false ? style.red("✗") : style.dim("·");
    console.log(`${mark} ${check.message}`);
    if (check.fix) console.log(`  ${style.dim("→")} ${check.fix}`);
  }
  const problems = checks.filter((check) => check.ok === false).length;
  console.log(problems === 0 ? `\n${style.green("Ready.")}` : `\n${problems} ${problems === 1 ? "thing" : "things"} to fix.`);
  return ok;
}
