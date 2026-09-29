/**
 * The OrbTorrent extension API.
 *
 * Extensions run inside OrbTorrent's sandboxed extension host, not Node.js or a
 * browser. They have no file system or network of their own: everything goes
 * through these functions, which OrbTorrent checks against the permissions in
 * package.json.
 */

// MARK: The environment

/** When a hook runs. */
export type HookEvent = "beforeStart" | "afterFinish";

interface Context {
  extension: { name: string; title: string; isDevelopment: boolean };
  entryPoint: { type: "hook" | "verify"; name: string; event?: HookEvent };
  preferences: Record<string, unknown>;
  /** The API version OrbTorrent provides. */
  api: string;
}

interface Bridge {
  call(method: string, params?: unknown): Promise<any>;
  readonly context: Context | null;
}

declare global {
  /** Your extension's settings. `orb build` fills this in from package.json, in orb-env.d.ts. */
  interface OrbPreferences {}

  // What OrbTorrent's extension host provides besides the JavaScript language itself.
  interface Console {
    log(...values: unknown[]): void;
    info(...values: unknown[]): void;
    debug(...values: unknown[]): void;
    trace(...values: unknown[]): void;
    warn(...values: unknown[]): void;
    error(...values: unknown[]): void;
  }
  var console: Console;
  function setTimeout<A extends unknown[]>(callback: (...args: A) => void, milliseconds?: number, ...args: A): number;
  function setInterval<A extends unknown[]>(callback: (...args: A) => void, milliseconds?: number, ...args: A): number;
  function clearTimeout(id: number | undefined): void;
  function clearInterval(id: number | undefined): void;
  function queueMicrotask(callback: () => void): void;
  function structuredClone<T>(value: T): T;
  function atob(data: string): string;
  function btoa(data: string): string;

  class TextEncoder {
    readonly encoding: "utf-8";
    encode(input?: string): Uint8Array;
  }
  class TextDecoder {
    constructor(label?: "utf-8" | "utf8");
    readonly encoding: "utf-8";
    decode(input?: ArrayBuffer | ArrayBufferView): string;
  }
  class URLSearchParams implements Iterable<[string, string]> {
    constructor(init?: string | Iterable<[string, string]> | Record<string, string>);
    readonly size: number;
    append(name: string, value: string): void;
    delete(name: string): void;
    get(name: string): string | null;
    getAll(name: string): string[];
    has(name: string): boolean;
    set(name: string, value: string): void;
    sort(): void;
    forEach(callback: (value: string, key: string, parent: URLSearchParams) => void): void;
    keys(): IterableIterator<string>;
    values(): IterableIterator<string>;
    entries(): IterableIterator<[string, string]>;
    [Symbol.iterator](): IterableIterator<[string, string]>;
    toString(): string;
  }
  class URL {
    constructor(url: string | URL, base?: string | URL);
    static canParse(url: string | URL, base?: string | URL): boolean;
    readonly protocol: string;
    readonly username: string;
    readonly password: string;
    readonly hostname: string;
    readonly port: string;
    readonly host: string;
    readonly origin: string;
    pathname: string;
    search: string;
    hash: string;
    readonly searchParams: URLSearchParams;
    readonly href: string;
    toString(): string;
    toJSON(): string;
  }
  var crypto: {
    getRandomValues<T extends ArrayBufferView>(array: T): T;
    randomUUID(): string;
  };
}

function bridge(): Bridge {
  const orb = (globalThis as { __orb?: Bridge }).__orb;
  if (!orb) {
    throw new Error("@orbtorrent/api only works inside OrbTorrent, or in `orb test`.");
  }
  return orb;
}

function context(): Context {
  const value = bridge().context;
  if (!value) throw new Error("The extension hasn't started yet.");
  return value;
}

/** About the extension and how it's running. */
export const environment = {
  /** The extension's `name` from package.json. */
  get extensionName(): string {
    return context().extension.name;
  },
  /** Whether it's loaded from a folder with `orb dev`, rather than installed. */
  get isDevelopment(): boolean {
    return context().extension.isDevelopment;
  },
  /** The hook or `verify` function running now. */
  get entryPoint(): Context["entryPoint"] {
    return context().entryPoint;
  },
  /** The API version this OrbTorrent provides. */
  get apiVersion(): string {
    return context().api;
  },
};

/** Your extension's settings, as the user set them, with defaults filled in. */
export function getPreferenceValues<T = OrbPreferences>(): T {
  return context().preferences as T;
}

// MARK: Downloads and results

/** A file in a download. */
export interface DownloadFile {
  index: number;
  /** Relative to the download's folder, including its top folder. Never an absolute path. */
  path: string;
  /** In bytes. */
  size: number;
  /** Whether the user chose to download it. */
  wanted: boolean;
}

/** The download a hook runs on. */
export interface Download {
  /** Its info hash. */
  id: string;
  name: string;
  /** Bytes of the wanted files. */
  size: number;
  /** Whether it's from a private tracker. */
  isPrivate: boolean;
  files: DownloadFile[];
}

/**
 * - `passed`: nothing wrong.
 * - `warning`: worth a look; the download carries on.
 * - `failed`: something's wrong. Before a download starts, this holds it until the user decides.
 * - `skipped`: the check didn't apply, or couldn't run.
 */
export type Status = "passed" | "warning" | "failed" | "skipped";

/** What a hook found, shown in the download's Checks tab. */
export interface Result {
  status: Status;
  /** One line, shown in the list. Say which file and why. */
  summary: string;
  /** Markdown, shown under Details. */
  details?: string;
  link?: { title: string; url: string };
}

/** A hook: the default export of `src/<hook name>.ts`. */
export type Hook = (download: Download) => Result | Promise<Result>;

/** What `verify` returns. */
export type VerifyResult = { ok: true; message?: string } | { ok: false; message: string };

/** The default export of the file `verify` names: checks the settings when the user presses Verify. */
export type Verify = (preferences: OrbPreferences) => VerifyResult | Promise<VerifyResult>;

// MARK: Network

/** One field of a form for `fetch`. */
export type FormPart =
  | { name: string; value: string }
  | { name: string; file: number; filename?: string; contentType?: string };

/** A multipart form, which can include the download's files. Make one with `files.formData`. */
export class FormBody {
  readonly parts: FormPart[] = [];

  append(name: string, value: string | DownloadFile, options: { filename?: string; contentType?: string } = {}): this {
    if (typeof value === "string") {
      this.parts.push({ name, value });
    } else {
      this.parts.push({ name, file: value.index, ...options });
    }
    return this;
  }
}

export interface RequestInit {
  method?: "GET" | "HEAD" | "POST" | "PUT" | "PATCH" | "DELETE";
  headers?: Record<string, string>;
  /** Text (use `JSON.stringify` for JSON), or a form from `files.formData`. */
  body?: string | FormBody;
}

export interface Headers {
  get(name: string): string | null;
  has(name: string): boolean;
  entries(): [string, string][];
}

export interface Response {
  readonly status: number;
  /** Whether the status is 200–299. */
  readonly ok: boolean;
  /** The address it came from, after any redirects. */
  readonly url: string;
  readonly headers: Headers;
  text(): Promise<string>;
  json<T = any>(): Promise<T>;
}

interface RawResponse {
  status: number;
  headers: Record<string, string>;
  body: string;
  url: string;
}

/**
 * An HTTPS request, to a host listed in `permissions.network`. Responses are
 * limited to 10 MB, and each request to 30 seconds.
 */
export async function fetch(url: string | URL, init: RequestInit = {}): Promise<Response> {
  const body = init.body === undefined ? null : init.body instanceof FormBody ? { multipart: init.body.parts } : String(init.body);
  const raw: RawResponse = await bridge().call("fetch", {
    url: String(url),
    method: init.method ?? "GET",
    headers: init.headers ?? {},
    body,
  });
  const headers = Object.fromEntries(Object.entries(raw.headers).map(([name, value]) => [name.toLowerCase(), value]));
  return {
    status: raw.status,
    ok: raw.status >= 200 && raw.status < 300,
    url: raw.url,
    headers: {
      get: (name) => headers[name.toLowerCase()] ?? null,
      has: (name) => name.toLowerCase() in headers,
      entries: () => Object.entries(headers),
    },
    text: async () => raw.body,
    json: async () => JSON.parse(raw.body),
  };
}

// MARK: Files

function fileIndex(file: DownloadFile | number): number {
  return typeof file === "number" ? file : file.index;
}

/** The download's files. Reading them needs `"files": "contents"` in permissions. */
export const files = {
  /** The file's SHA-256 fingerprint in lowercase hex, computed by OrbTorrent. Only after the download finishes. */
  sha256(file: DownloadFile | number): Promise<string> {
    return bridge().call("files.sha256", { file: fileIndex(file) });
  },

  /** A form to upload with `fetch`, whose files OrbTorrent streams from disk. */
  formData(fields: Record<string, string | DownloadFile>): FormBody {
    const form = new FormBody();
    for (const [name, value] of Object.entries(fields)) form.append(name, value);
    return form;
  },
};

// MARK: Progress and storage

/** Shows how far along the check is in the Checks tab, such as "Checking 3 of 10 files…". */
export function progress(update: { done?: number; total?: number; message?: string }): Promise<void> {
  return bridge().call("progress", update);
}

/** JSON values the extension keeps between runs, up to 1 MB in all. */
export const storage = {
  async get<T = unknown>(key: string): Promise<T | undefined> {
    const value = await bridge().call("storage.get", { key });
    return value === null ? undefined : (value as T);
  },
  set(key: string, value: unknown): Promise<void> {
    return bridge().call("storage.set", { key, value: value === undefined ? null : value });
  },
  remove(key: string): Promise<void> {
    return bridge().call("storage.remove", { key });
  },
  keys(): Promise<string[]> {
    return bridge().call("storage.keys", {});
  },
};

/** Waits, without using CPU time. */
export function sleep(milliseconds: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, milliseconds));
}
