import { randomUUID, webcrypto } from "node:crypto";
import vm from "node:vm";
import { Manifest } from "./manifest.js";

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
  /** Answers this many requests, then lets the next matching mock answer. */
  times?: number;
}

export interface HarnessFile {
  sha256?: string;
}

export interface HarnessOptions {
  manifest: Manifest;
  entryPoint: { type: "hook" | "verify"; name: string; event?: "beforeStart" | "afterFinish" };
  preferences: Record<string, unknown>;
  fetchMocks: FetchMock[];
  /** Files by index, once downloaded. */
  files: Record<number, HarnessFile>;
  storage: Record<string, unknown>;
  timeout: number;
}

export interface HarnessRun {
  outcome: { ok: true; value: unknown } | { ok: false; message: string; stack: string; timedOut?: boolean };
  logs: { level: string; message: string }[];
  fetched: { method: string; url: string }[];
  progress: { done?: number; total?: number; message?: string }[];
  storage: Record<string, unknown>;
}

class Refusal extends Error {}

/** A mock's URL matches exactly, or with `*` standing for any text. */
function matches(pattern: string, url: string): boolean {
  if (!pattern.includes("*")) return pattern === url;
  const expression = pattern.split("*").map((part) => part.replace(/[.+?^${}()|[\]\\]/g, "\\$&")).join(".*");
  return new RegExp(`^${expression}$`).test(url);
}

export async function runInHarness(script: string, args: unknown[], options: HarnessOptions): Promise<HarnessRun> {
  const run: HarnessRun = { outcome: { ok: true, value: null }, logs: [], fetched: [], progress: [], storage: { ...options.storage } };
  const { manifest } = options;
  const uses = new Map<FetchMock, number>();

  const file = (index: unknown): HarnessFile => {
    if (manifest.permissions.files !== "contents") {
      throw new Refusal("Reading files isn't allowed. Add \"files\": \"contents\" to permissions in package.json.");
    }
    if (typeof index !== "number") throw new Refusal("Pass a file from download.files.");
    if (options.entryPoint.event === "beforeStart") {
      throw new Refusal(`File ${index} isn't available: it isn't downloaded yet, or it isn't part of this download.`);
    }
    const entry = options.files[index];
    if (!entry) throw new Refusal(`File ${index} isn't available: it isn't downloaded yet, or it isn't part of this download.`);
    return entry;
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
    api: "1.0.0",
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
