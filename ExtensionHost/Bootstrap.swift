/// The JavaScript that sets up an extension's environment before its script
/// runs: the bridge to OrbTorrent, and the web APIs extensions expect that
/// JavaScriptCore doesn't have (timers, `console`, `URL`, `TextEncoder`,
/// `atob`, `crypto`).
enum Bootstrap {
    static let source = #"""
"use strict";
(() => {
  const nativeCall = __orbNativeCall;
  const nativeLog = __orbNativeLog;
  const nativeTimer = __orbNativeTimer;
  const nativeCancelTimer = __orbNativeCancelTimer;
  const nativeDone = __orbNativeDone;
  const nativeParseURL = __orbNativeParseURL;
  const nativeRandom = __orbNativeRandom;
  for (const name of ["__orbNativeCall", "__orbNativeLog", "__orbNativeTimer", "__orbNativeCancelTimer",
                      "__orbNativeDone", "__orbNativeParseURL", "__orbNativeRandom"]) {
    delete globalThis[name];
  }
  const hidden = (name, value) =>
    Object.defineProperty(globalThis, name, { value, enumerable: false, writable: false, configurable: false });
  const global = (name, value) =>
    Object.defineProperty(globalThis, name, { value, enumerable: false, writable: true, configurable: true });

  // Calls into OrbTorrent.
  const pending = new Map();
  let nextCall = 1;
  const call = (method, params) => new Promise((resolve, reject) => {
    const id = nextCall++;
    pending.set(id, { resolve, reject });
    nativeCall(id, String(method), JSON.stringify(params === undefined ? null : params));
  });
  hidden("__orbReply", (id, ok, json) => {
    const entry = pending.get(id);
    if (!entry) return;
    pending.delete(id);
    const value = JSON.parse(json);
    if (ok) {
      entry.resolve(value);
    } else {
      entry.reject(new Error(typeof value === "string" ? value : (value && value.message) || "OrbTorrent refused the request."));
    }
  });

  // console
  const describe = (value) => {
    if (typeof value === "string") return value;
    if (value instanceof Error) return value.stack ? `${value.name}: ${value.message}\n${value.stack}` : `${value.name}: ${value.message}`;
    if (value === undefined) return "undefined";
    if (typeof value === "function") return `[Function ${value.name || "anonymous"}]`;
    if (typeof value === "bigint") return `${value}n`;
    if (typeof value === "symbol") return value.toString();
    try {
      const text = JSON.stringify(value, (key, item) => typeof item === "bigint" ? `${item}n` : item);
      return text === undefined ? String(value) : text;
    } catch {
      return String(value);
    }
  };
  const logger = (level) => (...values) => nativeLog(level, values.map(describe).join(" "));
  global("console", Object.freeze({
    log: logger("log"), info: logger("info"), debug: logger("debug"), trace: logger("debug"),
    warn: logger("warn"), error: logger("error"),
  }));

  // Timers
  const timers = new Map();
  let nextTimer = 1;
  const addTimer = (callback, milliseconds, args, repeats) => {
    if (typeof callback !== "function") throw new TypeError("The timer's callback must be a function.");
    const id = nextTimer++;
    const delay = Math.max(0, Number(milliseconds) || 0);
    timers.set(id, { callback, args, repeats, delay });
    nativeTimer(id, delay);
    return id;
  };
  const clearTimer = (id) => {
    if (timers.delete(id)) nativeCancelTimer(id);
  };
  hidden("__orbFireTimer", (id) => {
    const timer = timers.get(id);
    if (!timer) return;
    if (timer.repeats) {
      nativeTimer(id, Math.max(timer.delay, 1));
    } else {
      timers.delete(id);
    }
    timer.callback(...timer.args);
  });
  global("setTimeout", (callback, milliseconds, ...args) => addTimer(callback, milliseconds, args, false));
  global("setInterval", (callback, milliseconds, ...args) => addTimer(callback, milliseconds, args, true));
  global("clearTimeout", clearTimer);
  global("clearInterval", clearTimer);
  global("queueMicrotask", (callback) => {
    if (typeof callback !== "function") throw new TypeError("queueMicrotask needs a function.");
    Promise.resolve().then(callback);
  });

  // Base64
  const alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
  global("btoa", (input) => {
    const text = String(input);
    let output = "";
    for (let i = 0; i < text.length; i += 3) {
      const count = Math.min(3, text.length - i);
      let triple = 0;
      for (let j = 0; j < 3; j++) {
        const code = j < count ? text.charCodeAt(i + j) : 0;
        if (code > 255) throw new Error("btoa: the string has characters outside Latin-1.");
        triple = (triple << 8) | code;
      }
      for (let j = 0; j < 4; j++) {
        output += j <= count ? alphabet[(triple >> (18 - 6 * j)) & 63] : "=";
      }
    }
    return output;
  });
  global("atob", (input) => {
    const text = String(input).replace(/[\t\n\f\r ]/g, "").replace(/=+$/, "");
    if (/[^A-Za-z0-9+/]/.test(text) || text.length % 4 === 1) throw new Error("atob: the string isn't valid base64.");
    let output = "";
    let buffer = 0;
    let bits = 0;
    for (const character of text) {
      buffer = (buffer << 6) | alphabet.indexOf(character);
      bits += 6;
      if (bits >= 8) {
        bits -= 8;
        output += String.fromCharCode((buffer >> bits) & 255);
        buffer &= (1 << bits) - 1;
      }
    }
    return output;
  });

  // Text encoding (UTF-8 only)
  const bytesOf = (input) => {
    if (input === undefined) return new Uint8Array(0);
    if (ArrayBuffer.isView(input)) return new Uint8Array(input.buffer, input.byteOffset, input.byteLength);
    return new Uint8Array(input);
  };
  class TextEncoder {
    get encoding() { return "utf-8"; }
    encode(input = "") {
      const bytes = [];
      for (const character of String(input)) {
        let point = character.codePointAt(0);
        if (point >= 0xD800 && point <= 0xDFFF) point = 0xFFFD;
        if (point < 0x80) {
          bytes.push(point);
        } else if (point < 0x800) {
          bytes.push(0xC0 | (point >> 6), 0x80 | (point & 63));
        } else if (point < 0x10000) {
          bytes.push(0xE0 | (point >> 12), 0x80 | ((point >> 6) & 63), 0x80 | (point & 63));
        } else {
          bytes.push(0xF0 | (point >> 18), 0x80 | ((point >> 12) & 63), 0x80 | ((point >> 6) & 63), 0x80 | (point & 63));
        }
      }
      return new Uint8Array(bytes);
    }
  }
  class TextDecoder {
    constructor(label = "utf-8") {
      if (!/^utf-?8$/i.test(String(label))) throw new RangeError(`TextDecoder only supports UTF-8, not ${label}.`);
    }
    get encoding() { return "utf-8"; }
    decode(input) {
      const bytes = bytesOf(input);
      let output = "";
      for (let i = 0; i < bytes.length;) {
        const lead = bytes[i];
        let point;
        let needed;
        if (lead < 0x80) { point = lead; needed = 0; }
        else if (lead >= 0xC2 && lead < 0xE0) { point = lead & 31; needed = 1; }
        else if (lead >= 0xE0 && lead < 0xF0) { point = lead & 15; needed = 2; }
        else if (lead >= 0xF0 && lead < 0xF5) { point = lead & 7; needed = 3; }
        else { output += "�"; i += 1; continue; }
        let read = 1;
        let valid = true;
        for (; read <= needed; read++) {
          const next = bytes[i + read];
          if (next === undefined || (next & 0xC0) !== 0x80) { valid = false; break; }
          point = (point << 6) | (next & 63);
        }
        if (!valid || (needed === 2 && point < 0x800) || (needed === 3 && (point < 0x10000 || point > 0x10FFFF))
            || (point >= 0xD800 && point <= 0xDFFF)) {
          output += "�";
          i += valid ? needed + 1 : read;
          continue;
        }
        output += String.fromCodePoint(point);
        i += needed + 1;
      }
      return output;
    }
  }
  global("TextEncoder", TextEncoder);
  global("TextDecoder", TextDecoder);

  // URLSearchParams and URL
  const decodeParameter = (text) => {
    try { return decodeURIComponent(text.replace(/\+/g, " ")); } catch { return text; }
  };
  const encodeParameter = (text) => encodeURIComponent(text).replace(/%20/g, "+")
    .replace(/[!'()~]/g, (character) => "%" + character.charCodeAt(0).toString(16).toUpperCase());
  const ownerURL = new WeakMap();
  class URLSearchParams {
    #entries = [];
    constructor(init = "") {
      if (typeof init === "string") {
        const text = init.startsWith("?") ? init.slice(1) : init;
        for (const part of text.split("&")) {
          if (!part) continue;
          const equals = part.indexOf("=");
          this.#entries.push(equals < 0
            ? [decodeParameter(part), ""]
            : [decodeParameter(part.slice(0, equals)), decodeParameter(part.slice(equals + 1))]);
        }
      } else if (init && typeof init[Symbol.iterator] === "function") {
        for (const [key, value] of init) this.#entries.push([String(key), String(value)]);
      } else if (init && typeof init === "object") {
        for (const key of Object.keys(init)) this.#entries.push([key, String(init[key])]);
      }
    }
    #changed() {
      const url = ownerURL.get(this);
      if (url) url.search = this.toString();
    }
    get size() { return this.#entries.length; }
    append(key, value) { this.#entries.push([String(key), String(value)]); this.#changed(); }
    delete(key) { this.#entries = this.#entries.filter(([name]) => name !== String(key)); this.#changed(); }
    get(key) { const entry = this.#entries.find(([name]) => name === String(key)); return entry ? entry[1] : null; }
    getAll(key) { return this.#entries.filter(([name]) => name === String(key)).map(([, value]) => value); }
    has(key) { return this.#entries.some(([name]) => name === String(key)); }
    set(key, value) {
      const name = String(key);
      const index = this.#entries.findIndex(([entry]) => entry === name);
      if (index < 0) {
        this.#entries.push([name, String(value)]);
      } else {
        this.#entries[index] = [name, String(value)];
        this.#entries = this.#entries.filter(([entry], position) => entry !== name || position === index);
      }
      this.#changed();
    }
    sort() { this.#entries.sort(([a], [b]) => (a < b ? -1 : a > b ? 1 : 0)); this.#changed(); }
    forEach(callback, thisArg) { for (const [key, value] of this.#entries) callback.call(thisArg, value, key, this); }
    keys() { return this.#entries.map(([key]) => key)[Symbol.iterator](); }
    values() { return this.#entries.map(([, value]) => value)[Symbol.iterator](); }
    entries() { return this.#entries.map((entry) => [...entry])[Symbol.iterator](); }
    [Symbol.iterator]() { return this.entries(); }
    toString() { return this.#entries.map(([key, value]) => `${encodeParameter(key)}=${encodeParameter(value)}`).join("&"); }
  }
  class URL {
    #parts;
    #searchParams;
    constructor(input, base) {
      const baseText = base === undefined ? undefined : String(base instanceof URL ? base.href : base);
      const json = nativeParseURL(String(input instanceof URL ? input.href : input), baseText);
      if (json === null || json === undefined) throw new TypeError(`Invalid URL: ${input}`);
      this.#parts = JSON.parse(json);
    }
    static canParse(input, base) {
      try { new URL(input, base); return true; } catch { return false; }
    }
    get protocol() { return this.#parts.protocol; }
    get username() { return this.#parts.username; }
    get password() { return this.#parts.password; }
    get hostname() { return this.#parts.hostname; }
    get port() { return this.#parts.port; }
    get host() { return this.#parts.hostname + (this.#parts.port ? ":" + this.#parts.port : ""); }
    get origin() { return this.#parts.hostname ? `${this.protocol}//${this.host}` : "null"; }
    get pathname() { return this.#parts.pathname; }
    set pathname(value) { const text = String(value); this.#parts.pathname = text.startsWith("/") ? text : "/" + text; }
    get search() { return this.#parts.search; }
    set search(value) {
      const text = String(value);
      this.#parts.search = text === "" || text === "?" ? "" : text.startsWith("?") ? text : "?" + text;
      this.#searchParams = undefined;
    }
    get hash() { return this.#parts.hash; }
    set hash(value) { const text = String(value); this.#parts.hash = text === "" || text === "#" ? "" : text.startsWith("#") ? text : "#" + text; }
    get searchParams() {
      if (!this.#searchParams) {
        this.#searchParams = new URLSearchParams(this.#parts.search);
        ownerURL.set(this.#searchParams, this);
      }
      return this.#searchParams;
    }
    get href() {
      const credentials = this.username ? this.username + (this.password ? ":" + this.password : "") + "@" : "";
      const authority = this.hostname ? `//${credentials}${this.host}` : "";
      return `${this.protocol}${authority}${this.pathname}${this.search}${this.hash}`;
    }
    toString() { return this.href; }
    toJSON() { return this.href; }
  }
  global("URLSearchParams", URLSearchParams);
  global("URL", URL);

  // crypto (random values only)
  global("crypto", Object.freeze({
    getRandomValues(array) {
      if (!ArrayBuffer.isView(array)) throw new TypeError("getRandomValues needs a typed array.");
      const bytes = new Uint8Array(array.buffer, array.byteOffset, array.byteLength);
      if (bytes.length > 65536) throw new Error("getRandomValues can fill at most 65,536 bytes at a time.");
      const random = nativeRandom(bytes.length);
      for (let i = 0; i < bytes.length; i++) bytes[i] = random[i];
      return array;
    },
    randomUUID() {
      const bytes = nativeRandom(16);
      bytes[6] = (bytes[6] & 15) | 64;
      bytes[8] = (bytes[8] & 63) | 128;
      const hex = bytes.map((byte) => byte.toString(16).padStart(2, "0")).join("");
      return `${hex.slice(0, 8)}-${hex.slice(8, 12)}-${hex.slice(12, 16)}-${hex.slice(16, 20)}-${hex.slice(20)}`;
    },
  }));
  global("structuredClone", (value) => value === undefined ? undefined : JSON.parse(JSON.stringify(value)));

  // Running the extension
  let context = null;
  hidden("__orb", Object.freeze({
    call,
    get context() { return context; },
  }));
  const fail = (error) => {
    const message = error instanceof Error ? error.message : describe(error);
    const stack = error instanceof Error ? String(error.stack || "") : "";
    nativeDone(false, JSON.stringify({ message, stack }));
  };
  hidden("__orbStart", (name, argumentsJSON, contextJSON) => {
    context = Object.freeze(JSON.parse(contextJSON));
    let entry;
    try {
      const module = globalThis.__orbExtension;
      if (module === undefined) {
        throw new Error("The extension's script didn't export anything. Build it with `orb build`.");
      }
      entry = name === "default" ? (module.default ?? module) : module[name];
      if (typeof entry !== "function") {
        throw new Error(name === "default"
          ? "The extension's script has no default export. Export the hook with `export default async function …`."
          : `The extension's script has no function named ${name}.`);
      }
    } catch (error) {
      fail(error);
      return;
    }
    Promise.resolve()
      .then(() => entry(...JSON.parse(argumentsJSON)))
      .then((value) => {
        let json;
        try {
          json = JSON.stringify(value === undefined ? null : value);
        } catch (error) {
          fail(new Error(`The result couldn't be turned into JSON: ${error.message}`));
          return;
        }
        nativeDone(true, json === undefined ? "null" : json);
      }, fail);
  });
})();
"""#
}
