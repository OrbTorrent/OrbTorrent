import { watch } from "node:fs";
import { build } from "./build.js";
import { AppConnection, appName, Message } from "./connection.js";
import { CommandError, printError, printJSON, style } from "./output.js";

const levels: Record<string, (text: string) => string> = {
  error: style.red,
  warn: style.yellow,
  debug: style.dim,
};

export function formatEvent(message: Message): string | undefined {
  const where = message.download ? style.dim(`[${message.hook ?? message.entryPoint ?? ""} · ${message.download.name}] `) : "";
  switch (message.type) {
    case "log":
      return where + (levels[message.level] ?? ((text: string) => text))(message.message);
    case "check": {
      const mark = { passed: style.green("✓"), warning: style.yellow("!"), failed: style.red("✗"), skipped: style.dim("–") }[message.status as string] ?? style.dim("…");
      return `${where}${mark} ${message.status}: ${message.summary ?? ""}`;
    }
    case "progress":
      return where + style.dim(`${message.message ?? ""} ${message.total ? `(${message.done ?? 0} of ${message.total})` : ""}`.trim());
    default:
      return undefined;
  }
}

async function load(connection: AppConnection, dist: string): Promise<Message> {
  const timer = setTimeout(() => console.log(style.dim("Waiting for you to allow it in OrbTorrent…")), 1500);
  try {
    return await connection.request({ type: "load", path: dist }, ["loaded"]);
  } finally {
    clearTimeout(timer);
  }
}

/** Loads the extension into OrbTorrent, rebuilds it on every save and shows its logs. */
export async function devCommand(folder: string): Promise<void> {
  const connection = await AppConnection.open();
  let built = await build(folder);
  for (const warning of built.warnings) console.log(style.yellow(`! ${warning}`));
  const loaded = await load(connection, built.dist);
  const name = built.manifest.name;
  console.log(`${style.green("✓")} Loaded ${style.bold(built.manifest.title)} into OrbTorrent${loaded.replacesOfficial ? " as a development copy of the official one" : ""}.`);
  console.log(style.dim("Rebuilding on every save. Press Control-C to stop; the extension stays in OrbTorrent."));
  connection.send({ type: "watch", name });
  void connection.listen((message) => {
    if (message.name !== undefined && message.name !== name) return;
    const text = formatEvent(message);
    if (text) console.log(text);
    if (message.type === "closed") {
      console.log(style.red("OrbTorrent closed the connection."));
      process.exit(1);
    }
  });

  let timer: NodeJS.Timeout | undefined;
  let building = false;
  const rebuild = async () => {
    if (building) return;
    building = true;
    try {
      built = await build(folder);
      await connection.request({ type: "load", path: built.dist }, ["loaded"]);
      console.log(`${style.green("✓")} Rebuilt and reloaded ${style.dim(new Date().toLocaleTimeString())}`);
    } catch (error) {
      printError(error, false);
    } finally {
      building = false;
    }
  };
  const ignored = (file: string | null) => !file || file.startsWith("dist") || file.startsWith("node_modules")
    || file === "orb-env.d.ts" || file.endsWith(".orbext") || file.startsWith(".");
  watch(folder, { recursive: true }, (_, file) => {
    if (ignored(file)) return;
    clearTimeout(timer);
    timer = setTimeout(rebuild, 150);
  });
  await new Promise(() => {});
}

/** Runs a hook on one of your downloads in OrbTorrent and prints what it returned. */
export async function runCommand(folder: string, hookName: string | undefined, download: string | undefined, json: boolean): Promise<boolean> {
  const built = await build(folder);
  const hook = hookName ?? (built.manifest.hooks.length === 1 ? built.manifest.hooks[0].name : undefined);
  if (!hook || !built.manifest.hooks.some((candidate) => candidate.name === hook)) {
    throw new CommandError(hookName ? `package.json has no hook named “${hookName}”.` : "Say which hook to run.",
      [`Hooks: ${built.manifest.hooks.map((candidate) => candidate.name).join(", ")}`]);
  }
  if (!download) throw new CommandError("Say which download to run it on, with --download <name or info hash>.");
  const connection = await AppConnection.open();
  try {
    await load(connection, built.dist);
    const events: Message[] = [];
    const result = await connection.request({ type: "run", name: built.manifest.name, hook, download }, ["result"], (message) => {
      events.push(message);
      if (!json) {
        const text = formatEvent(message);
        if (text) console.log(text);
      }
    });
    if (json) {
      printJSON({ ok: result.outcome === "returned", ...result, logs: events.filter((event) => event.type === "log") });
    } else if (result.outcome === "returned") {
      const mark = { passed: style.green("✓"), warning: style.yellow("!"), failed: style.red("✗"), skipped: style.dim("–") }[result.status as string] ?? "";
      console.log(`${mark} ${style.bold(result.status)}: ${result.summary}`);
      if (result.details) console.log(style.dim(result.details));
      if (result.link) console.log(style.dim(`${result.link.title}: ${result.link.url}`));
    } else {
      console.log(`${style.red("✗")} ${result.message}`);
    }
    return result.outcome === "returned";
  } finally {
    connection.close();
  }
}

function formatSize(bytes: number): string {
  const units = ["bytes", "KB", "MB", "GB", "TB"];
  let size = bytes;
  let unit = 0;
  while (size >= 1000 && unit < units.length - 1) {
    size /= 1000;
    unit++;
  }
  return `${unit === 0 ? size : size.toFixed(1)} ${units[unit]}`;
}

/** Lists the downloads in OrbTorrent, to choose one for `orb run`. */
export async function downloadsCommand(json: boolean): Promise<boolean> {
  const connection = await AppConnection.open();
  try {
    const reply = await connection.request({ type: "downloads" }, ["downloads"]);
    const downloads = (reply.downloads ?? []) as { id: string; name: string; size: number; progress: number; finished: boolean }[];
    if (json) {
      printJSON({ ok: true, downloads });
    } else if (downloads.length === 0) {
      console.log(`There are no downloads in ${appName} yet. Add one, such as a Linux image, to try a hook on.`);
    } else {
      for (const download of downloads) {
        const state = download.finished ? style.green("finished") : `${Math.floor(download.progress * 100)}%`.padEnd(8);
        console.log(`${state}  ${formatSize(download.size).padStart(9)}  ${download.name}  ${style.dim(download.id)}`);
      }
      console.log(style.dim(`\nRun a hook on one with \`npx orb run <hook> --download "<name or info hash>"\`. An afterFinish hook needs a finished one.`));
    }
    return true;
  } finally {
    connection.close();
  }
}
