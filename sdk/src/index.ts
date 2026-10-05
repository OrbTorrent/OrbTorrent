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
export type HookEvent = "beforeStart" | "afterFinish" | "afterChecks";

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
  /**
   * Once the download has finished: whether this file finished since the hook
   * last ran on it, such as one the user chose to download later. Every file
   * is new the first time, and when the user runs the hook again.
   */
  isNew?: boolean;
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
  /** For an `afterChecks` hook: what the other extensions' checks found, worst first. */
  checks?: CheckResult[];
  /** For an `afterChecks` hook: whether a check is holding it before it starts. Otherwise it's finished. */
  isHeld?: boolean;
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
  /**
   * Also shows the summary as a notification, such as "Added English
   * subtitles". A warning or failure after a download finishes, and a
   * download held before it starts, are notifications already.
   */
  notify?: boolean;
  /**
   * What it found about particular files. OrbTorrent marks each problem
   * beside its file, and the result counts as no better than its worst file.
   * Each result replaces the hook's last one, so name every file you know
   * about, not only the new ones.
   */
  files?: FileResult[];
}

/** What a hook found about one of the download's files. */
export interface FileResult {
  /** A file from `download.files`, or its index. */
  file: DownloadFile | number;
  status: "passed" | "warning" | "failed";
  /** Why, in a few words, such as "5 of 70 engines call it malicious". */
  summary?: string;
  link?: { title: string; url: string };
}

/** Another extension's result on the download, as an `afterChecks` hook sees it. */
export interface CheckResult {
  extension: { name: string; title: string };
  /** The hook's name. */
  hook: string;
  event: "beforeStart" | "afterFinish";
  /** `didNotFinish` when it threw, crashed or went over a limit. */
  status: Status | "didNotFinish";
  summary: string;
  details?: string;
  link?: { title: string; url: string };
  /** What it found about particular files, problems first. */
  files?: { index: number; path: string; status: "passed" | "warning" | "failed"; summary?: string; link?: { title: string; url: string } }[];
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
  /** The body's bytes, such as an image or a zip file. */
  bytes(): Promise<Uint8Array>;
  arrayBuffer(): Promise<ArrayBuffer>;
}

interface RawResponse {
  status: number;
  headers: Record<string, string>;
  /** UTF-8 text, or Base64 when `encoding` says so. */
  body: string;
  encoding?: "base64";
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
  const bytes = () => raw.encoding === "base64" ? fromBase64(raw.body) : new TextEncoder().encode(raw.body);
  const text = () => raw.encoding === "base64" ? new TextDecoder().decode(fromBase64(raw.body)) : raw.body;
  return {
    status: raw.status,
    ok: raw.status >= 200 && raw.status < 300,
    url: raw.url,
    headers: {
      get: (name) => headers[name.toLowerCase()] ?? null,
      has: (name) => name.toLowerCase() in headers,
      entries: () => Object.entries(headers),
    },
    text: async () => text(),
    json: async () => JSON.parse(text()),
    bytes: async () => bytes(),
    arrayBuffer: async () => {
      const view = bytes();
      return view.buffer.slice(view.byteOffset, view.byteOffset + view.byteLength) as ArrayBuffer;
    },
  };
}

// MARK: Base64, for bytes on their way to and from OrbTorrent

const base64Alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
const base64Values = new Uint8Array(128).fill(255);
for (let index = 0; index < base64Alphabet.length; index++) base64Values[base64Alphabet.charCodeAt(index)] = index;

function toBase64(bytes: Uint8Array): string {
  const parts: string[] = [];
  let line = "";
  for (let index = 0; index < bytes.length; index += 3) {
    const a = bytes[index];
    const b = bytes[index + 1];
    const c = bytes[index + 2];
    line += base64Alphabet[a >> 2] + base64Alphabet[((a & 3) << 4) | ((b ?? 0) >> 4)]
      + (b === undefined ? "=" : base64Alphabet[((b & 15) << 2) | ((c ?? 0) >> 6)])
      + (c === undefined ? "=" : base64Alphabet[c & 63]);
    if (line.length >= 8192) {
      parts.push(line);
      line = "";
    }
  }
  parts.push(line);
  return parts.join("");
}

function fromBase64(text: string): Uint8Array {
  const clean = text.replace(/[^A-Za-z0-9+/]/g, "");
  const output = new Uint8Array(Math.floor((clean.length * 3) / 4));
  let length = 0;
  for (let index = 0; index < clean.length; index += 4) {
    const a = base64Values[clean.charCodeAt(index)];
    const b = base64Values[clean.charCodeAt(index + 1)];
    const c = index + 2 < clean.length ? base64Values[clean.charCodeAt(index + 2)] : undefined;
    const d = index + 3 < clean.length ? base64Values[clean.charCodeAt(index + 3)] : undefined;
    output[length++] = (a << 2) | (b >> 4);
    if (c !== undefined) output[length++] = ((b & 15) << 4) | (c >> 2);
    if (d !== undefined && c !== undefined) output[length++] = ((c & 3) << 6) | d;
  }
  return output.subarray(0, length);
}

// MARK: Files

function fileIndex(file: DownloadFile | number): number {
  return typeof file === "number" ? file : file.index;
}

/** A file `files.save` added. */
export interface SavedFile {
  /** Relative to the download's folder, like a `DownloadFile`'s path. */
  path: string;
  /** In bytes. */
  size: number;
}

/**
 * The download's files. Reading them needs `"files": "contents"` in
 * permissions, and adding files next to them needs `"files": "add"`, or
 * `["contents", "add"]` for both.
 */
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

  /**
   * Adds a file next to one of the download's, named after it with `suffix`:
   * `files.save(video, ".en.srt", text)` saves `Film.2024.en.srt` beside
   * `Film.2024.mkv`. Only after the download finishes, and only subtitles,
   * text, images and checksums, up to 10 MB each. It never replaces a file,
   * except one this hook added to this download before.
   *
   * @param suffix Starts with ".", "-", "_" or a space, and ends with an
   *   extension, such as ".en.srt" or "-poster.jpg".
   * @param contents Text, saved as UTF-8, or bytes.
   */
  save(file: DownloadFile | number, suffix: string, contents: string | Uint8Array | ArrayBuffer): Promise<SavedFile> {
    const encoded = typeof contents === "string"
      ? { text: contents }
      : { base64: toBase64(ArrayBuffer.isView(contents)
          ? new Uint8Array(contents.buffer, contents.byteOffset, contents.byteLength)
          : new Uint8Array(contents)) };
    return bridge().call("files.save", { file: fileIndex(file), suffix, contents: encoded });
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
