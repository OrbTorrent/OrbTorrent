import { randomUUID, webcrypto } from "node:crypto";
import vm from "node:vm";
import { Manifest } from "./manifest.js";
import { sdkVersion } from "./paths.js";

// Runs a built entry point the way OrbTorrent's extension host does: only the
// JavaScript language and the host's few web APIs, with every call answered
// here from a test's mocks, under the same rules and messages as OrbTorrent.

export interface FetchMock {
  url: string;
  method?: string;
  status?: number;
  headers?: Record<string, string>;
  json?: unknown;
  text?: string;
  /** A body of bytes, such as an image or a zip file, in Base64. */
  base64?: string;
  /** Answers this many requests, then lets the next matching mock answer. */
  times?: number;
}

export interface HarnessFile {
  path?: string;
  /** Unless false. */
  wanted?: boolean;
  sha256?: string;
}

export interface HarnessOptions {
  manifest: Manifest;
  entryPoint: { type: "hook" | "verify"; name: string; event?: "beforeStart" | "afterFinish" };
  preferences: Record<string, unknown>;
  fetchMocks: FetchMock[];
  /** The download's files by index. After it finishes, the wanted ones are on disk. */
  files: Record<number, HarnessFile>;
  /** Other files next to the download's, relative to its folder, as `files.save` would find them. */
  alsoOnDisk?: string[];
  storage: Record<string, unknown>;
  timeout: number;
}

export interface HarnessRun {
  outcome: { ok: true; value: unknown } | { ok: false; message: string; stack: string; timedOut?: boolean };
  logs: { level: string; message: string }[];
  fetched: { method: string; url: string }[];
  progress: { done?: number; total?: number; message?: string }[];
  storage: Record<string, unknown>;
  /** Files `files.save` added, with their text when they're UTF-8. */
  saved: { path: string; size: number; text?: string }[];
}

// The same rules and words as OrbTorrent's ExtensionFileAdder.swift.
const fileKinds: [string, string[]][] = [
  ["subtitles", ["srt", "ass", "ssa", "vtt", "sub", "idx", "sup", "smi", "lrc"]],
  ["text", ["txt", "nfo", "md", "json", "xml", "csv", "cue"]],
  ["images", ["jpg", "jpeg", "png", "webp", "gif", "heic"]],
  ["checksums", ["sfv", "md5", "sha1", "sha256"]],
];
const addableExtensions = new Set(fileKinds.flatMap(([, extensions]) => extensions));
const maximumAddedFile = 10 << 20;
const maximumAddedRun = 50 << 20;
const maximumAddedFiles = 200;
const lastExtension = (text: string) => (text.includes(".") ? text.slice(text.lastIndexOf(".") + 1) : "");

export function isSuffix(text: string): boolean {
  if ([...text].length > 64 || !".-_ ".includes(text[0] ?? "x")) return false;
  if (/[/\\:\u0000-\u001F\u007F-\u009F]/.test(text)) return false;
  const extension = lastExtension(text);
  return extension.length > 0 && extension.length <= 10 && /^[A-Za-z0-9]+$/.test(extension);
}

class Refusal extends Error {}

/** A mock's URL matches exactly, or with `*` standing for any text. */
function matches(pattern: string, url: string): boolean {
  if (!pattern.includes("*")) return pattern === url;
  const expression = pattern.split("*").map((part) => part.replace(/[.+?^${}()|[\]\\]/g, "\\$&")).join(".*");
  return new RegExp(`^${expression}$`).test(url);
}

export async function runInHarness(script: string, args: unknown[], options: HarnessOptions): Promise<HarnessRun> {
  const run: HarnessRun = { outcome: { ok: true, value: null }, logs: [], fetched: [], progress: [], storage: { ...options.storage }, saved: [] };
  const unavailable = (index: unknown) => new Refusal(`File ${index} isn't available: it isn't downloaded yet, or it isn't part of this download.`);
  /** A wanted file of the finished download, as OrbTorrent has it on disk. */
  const onDisk = (index: unknown): HarnessFile => {
    if (typeof index !== "number") throw new Refusal("Pass a file from download.files.");
    const entry = options.files[index];
    if (options.entryPoint.event !== "afterFinish" || !entry || entry.wanted === false) throw unavailable(index);
    return entry;
  };
  let addedBytes = 0;
  const { manifest } = options;
  const uses = new Map<FetchMock, number>();

  const file = (index: unknown): HarnessFile => {
    if (!manifest.permissions.files.includes("contents")) {
      throw new Refusal("Reading files isn't allowed. Add \"files\": \"contents\" to permissions in package.json.");
    }
    return onDisk(index);
  };

  const save = (params: any): { path: string; size: number } => {
    if (!manifest.permissions.files.includes("add")) {
      throw new Refusal("Adding files isn't allowed. Add \"files\": \"add\" to permissions in package.json, or [\"contents\", \"add\"] to read files too.");
    }
    if (typeof params?.file !== "number") throw new Refusal("Pass a file from download.files.");
    const source = onDisk(params.file);
    const suffix = typeof params?.suffix === "string" ? params.suffix : undefined;
    if (suffix === undefined || !isSuffix(suffix)) {
      throw new Refusal(`“${suffix ?? ""}” can't be added to a file's name. A suffix starts with “.”, “-”, “_” or a space, and ends with an extension, such as “.en.srt”.`);
    }
    const kind = lastExtension(suffix).toLowerCase();
    if (!addableExtensions.has(kind)) {
      const all = fileKinds.flatMap(([, extensions]) => extensions).map((extension) => `.${extension}`).join(", ");
      throw new Refusal(`Extensions can't add .${kind} files, only subtitles, text, images and checksums: ${all}.`);
    }
    const sourcePath = source.path ?? "";
    const slash = sourcePath.lastIndexOf("/");
    const folder = slash >= 0 ? sourcePath.slice(0, slash + 1) : "";
    const fileName = sourcePath.slice(slash + 1);
    const dot = fileName.lastIndexOf(".");
    const name = (dot > 0 ? fileName.slice(0, dot) : fileName) + suffix;
    if (Buffer.byteLength(name) > 255) throw new Refusal(`“${name}” is too long for a file name.`);
    const contents = params?.contents ?? {};
    const bytes = typeof contents.text === "string" ? Buffer.from(contents.text, "utf8")
      : typeof contents.base64 === "string" ? Buffer.from(contents.base64, "base64") : undefined;
    if (!bytes) throw new Refusal("files.save needs the file's contents: text, or bytes as a Uint8Array.");
    if (bytes.length > maximumAddedFile) throw new Refusal(`“${name}” is larger than 10 MB, the most an extension can add in one file.`);
    if (run.saved.length >= maximumAddedFiles) {
      throw new Refusal(`This run has already added ${maximumAddedFiles} files, the most an extension can add in one run.`);
    }
    if (addedBytes + bytes.length > maximumAddedRun) {
      throw new Refusal("This run has already added nearly 50 MB, the most an extension can add in one run.");
    }
    const path = folder + name;
    const existing = new Set([
      ...Object.values(options.files).filter((entry) => entry.wanted !== false).map((entry) => entry.path ?? ""),
      ...(options.alsoOnDisk ?? []),
      ...run.saved.map((saved) => saved.path),
    ]);
    if (existing.has(path)) throw new Refusal(`“${name}” already exists. An extension can't replace a file it didn't add.`);
    addedBytes += bytes.length;
    const text = bytes.toString("utf8");
    run.saved.push({ path, size: bytes.length, ...(Buffer.from(text, "utf8").equals(bytes) && { text }) });
    return { path, size: bytes.length };
  };

  const handle = async (method: string, params: any): Promise<unknown> => {
    switch (method) {
      case "fetch": {
        let url: URL;
        try {
          url = new URL(String(params?.url));
        } catch {
          throw new Refusal("fetch needs an https:// address.");
        }
        const host = url.hostname.toLowerCase();
        if (url.protocol !== "https:") {
          throw new Refusal(`Request to ${url.href} was refused: extensions can only use https:// addresses.`);
        }
        if (!manifest.permissions.network.includes(host)) {
          throw new Refusal(`Request to ${host} was refused. Add "${host}" to permissions.network in package.json.`);
        }
        const requestMethod = String(params?.method ?? "GET").toUpperCase();
        if (params?.body && typeof params.body === "object") {
          for (const part of params.body.multipart ?? []) {
            if (part.file !== undefined) file(part.file);
          }
        }
        run.fetched.push({ method: requestMethod, url: url.href });
        const mock = options.fetchMocks.find((candidate) =>
          (candidate.method ?? "GET").toUpperCase() === requestMethod && matches(candidate.url, url.href)
          && (candidate.times === undefined || (uses.get(candidate) ?? 0) < candidate.times));
        if (mock) uses.set(mock, (uses.get(mock) ?? 0) + 1);
        if (!mock) {
          throw new Refusal(`The test has no mock for ${requestMethod} ${url.href}. Add one to "mocks": { "fetch": [...] }.`);
        }
        const headers = { ...(mock.json !== undefined ? { "content-type": "application/json" } : {}), ...mock.headers };
        if (mock.base64 !== undefined) {
          // As OrbTorrent sends a body: UTF-8 text as it is, anything else in Base64.
          const bytes = Buffer.from(mock.base64, "base64");
          const text = bytes.toString("utf8");
          const isText = Buffer.from(text, "utf8").equals(bytes);
          return { status: mock.status ?? 200, headers, body: isText ? text : mock.base64, ...(!isText && { encoding: "base64" }), url: url.href };
        }
        return {
          status: mock.status ?? 200,
          headers,
          body: mock.json !== undefined ? JSON.stringify(mock.json) : mock.text ?? "",
          url: url.href,
        };
      }
      case "files.sha256": {
        const entry = file(params?.file);
        if (!entry.sha256) {
          throw new Refusal(`The test gives file ${params.file} no "sha256". Add one to its download.files entry.`);
        }
        return entry.sha256;
      }
      case "files.save":
        return save(params);
      case "progress":
        run.progress.push({ done: params?.done, total: params?.total, message: params?.message });
        return null;
      case "storage.get":
        return run.storage[String(params?.key)] ?? null;
      case "storage.set": {
        const next = { ...run.storage };
        if (params?.value === null || params?.value === undefined) delete next[String(params?.key)];
        else next[String(params?.key)] = params.value;
        if (JSON.stringify(next).length > 1 << 20) {
          throw new Refusal("Storage is full: an extension can keep up to 1 MB. Remove keys it no longer needs.");
        }
        run.storage = next;
        return null;
      }
      case "storage.remove":
        delete run.storage[String(params?.key)];
        return null;
      case "storage.keys":
        return Object.keys(run.storage).sort();
      default:
        throw new Refusal(`OrbTorrent doesn't know “${method}”. Update OrbTorrent, or check the @orbtorrent/api version.`);
    }
  };

  const describe = (value: unknown): string => {
    if (typeof value === "string") return value;
    if (value instanceof Error || (value && typeof value === "object" && "stack" in value && "message" in value)) {
      const error = value as Error;
      return `${error.name}: ${error.message}${error.stack ? `\n${error.stack}` : ""}`;
    }
    if (value === undefined) return "undefined";
    try {
      return JSON.stringify(value) ?? String(value);
    } catch {
      return String(value);
    }
  };
  const logger = (level: string) => (...values: unknown[]) => run.logs.push({ level, message: values.map(describe).join(" ") });

  // Timers run on a virtual clock, so a hook that waits out a rate limit is
  // tested in moments: each timer fires as soon as nothing else is pending,
  // and Date.now() moves on by the time it waited.
  let now = Date.now();
  let nextTimer = 1;
  let pumping = false;
  const timers: { id: number; at: number; callback: (...args: unknown[]) => void; args: unknown[]; every?: number }[] = [];
  const pump = () => {
    pumping = false;
    timers.sort((a, b) => a.at - b.at || a.id - b.id);
    const timer = timers.shift();
    if (!timer) return;
    now = Math.max(now, timer.at);
    if (timer.every !== undefined) timers.push({ ...timer, at: timer.at + timer.every });
    schedule();
    timer.callback(...timer.args);
  };
  const schedule = () => {
    if (!pumping && timers.length > 0) {
      pumping = true;
      setImmediate(pump);
    }
  };
  const addTimer = (every: boolean) => (callback: (...args: unknown[]) => void, milliseconds = 0, ...args: unknown[]) => {
    const delay = Math.max(0, Number(milliseconds) || 0);
    const id = nextTimer++;
    timers.push({ id, at: now + delay, callback, args, ...(every && { every: Math.max(delay, 1) }) });
    schedule();
    return id;
  };
  const clearTimer = (id: number) => {
    const index = timers.findIndex((timer) => timer.id === id);
    if (index >= 0) timers.splice(index, 1);
  };

  const sandbox = vm.createContext({
    console: { log: logger("log"), info: logger("info"), debug: logger("debug"), trace: logger("debug"), warn: logger("warn"), error: logger("error") },
    setTimeout: addTimer(false), setInterval: addTimer(true), clearTimeout: clearTimer, clearInterval: clearTimer,
    queueMicrotask, structuredClone,
    URL, URLSearchParams, TextEncoder, TextDecoder, atob, btoa,
    crypto: { randomUUID: () => randomUUID(), getRandomValues: (array: any) => webcrypto.getRandomValues(array) },
  });
  // Values made in the test's own realm, so the extension's checks on them behave as in OrbTorrent.
  const realm = vm.runInContext("({ parse: JSON.parse, Error })", sandbox) as { parse: (text: string) => unknown; Error: ErrorConstructor };
  (vm.runInContext("(now) => { Date.now = now; }", sandbox) as (now: () => number) => void)(() => now);
  const context = {
    extension: { name: manifest.name, title: manifest.title, isDevelopment: true },
    entryPoint: options.entryPoint,
    preferences: options.preferences,
    api: sdkVersion.split(".").slice(0, 2).join(".") + ".0",
  };
  sandbox.__orb = Object.freeze({
    call: (method: string, params: unknown) =>
      handle(method, JSON.parse(JSON.stringify(params ?? null))).then(
        (value) => realm.parse(JSON.stringify(value ?? null)),
        (error) => {
          throw new realm.Error(error instanceof Error ? error.message : String(error));
        },
      ),
    context: realm.parse(JSON.stringify(context)),
  });

  let timer: NodeJS.Timeout | undefined;
  try {
    vm.runInContext(script, sandbox, { filename: "extension.js", timeout: options.timeout });
    const module = sandbox.__orbExtension;
    const entry = module?.default ?? module;
    if (typeof entry !== "function") {
      throw new Error("The extension's script has no default export. Export the hook with `export default async function …`.");
    }
    sandbox.__orbArguments = realm.parse(JSON.stringify(args));
    const pending = vm.runInContext("Promise.resolve(__orbExtension.default(...__orbArguments))", sandbox, { timeout: options.timeout });
    const timeout = new Promise((_, reject) => {
      timer = setTimeout(() => reject(Object.assign(new Error(`It didn't finish within ${options.timeout / 1000} s.`), { timedOut: true })), options.timeout);
    });
    const value = await Promise.race([pending, timeout]);
    run.outcome = { ok: true, value: JSON.parse(JSON.stringify(value ?? null)) };
  } catch (error: any) {
    const timedOut = error?.timedOut === true || error?.code === "ERR_SCRIPT_EXECUTION_TIMEOUT";
    run.outcome = { ok: false, message: String(error?.message ?? error), stack: String(error?.stack ?? ""), ...(timedOut && { timedOut }) };
  } finally {
    clearTimeout(timer);
  }
  return run;
}
