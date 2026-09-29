// OrbTorrent's ESLint rules for extensions: the recommended JavaScript and
// TypeScript rules, and errors for what doesn't exist where extensions run.
import js from "@eslint/js";
import { defineConfig } from "eslint/config";
import tseslint from "typescript-eslint";

const missing = (name, instead) => ({ name, message: `${name} doesn't exist where extensions run. ${instead}` });

export default defineConfig([
  { ignores: ["dist/**", "node_modules/**", "orb-env.d.ts"] },
  js.configs.recommended,
  tseslint.configs.recommended,
  {
    files: ["**/*.{ts,tsx,js,jsx,mjs}"],
    languageOptions: {
      globals: Object.fromEntries([
        "console", "setTimeout", "setInterval", "clearTimeout", "clearInterval", "queueMicrotask", "structuredClone",
        "atob", "btoa", "TextEncoder", "TextDecoder", "URL", "URLSearchParams", "crypto",
      ].map((name) => [name, "readonly"])),
    },
    rules: {
      "no-restricted-globals": [
        "error",
        missing("process", "Use getPreferenceValues and environment from @orbtorrent/api."),
        missing("Buffer", "Use Uint8Array, TextEncoder and TextDecoder."),
        missing("require", "Use import."),
        missing("window", "Extensions don't run in a browser."),
        missing("document", "Extensions don't run in a browser."),
        missing("__dirname", "Extensions have no files of their own to read."),
        missing("fetch", "Import fetch from @orbtorrent/api."),
      ],
      "no-restricted-imports": [
        "error",
        {
          patterns: [{
            group: ["node:*", "fs", "fs/*", "path", "http", "https", "net", "dns", "tls", "child_process", "crypto", "os", "buffer", "worker_threads"],
            message: "Extensions don't run in Node.js. Use fetch, files and storage from @orbtorrent/api.",
          }],
        },
      ],
    },
  },
]);
