import { readFileSync } from "node:fs";
import { join } from "node:path";

// Mirrors OrbTorrent's own checks (ExtensionManifest.swift), with the same
// messages, so `orb build` catches what OrbTorrent would refuse.

export type HookEvent = "beforeStart" | "afterFinish";

export interface Hook {
  name: string;
  title: string;
  description?: string;
  event: HookEvent;
}

export interface Preference {
  name: string;
  type: "textfield" | "password" | "checkbox" | "dropdown";
  title: string;
  description?: string;
  required: boolean;
  placeholder?: string;
  label?: string;
  default?: string | boolean;
  data?: { title: string; value: string }[];
}

export interface Manifest {
  name: string;
  title: string;
  description: string;
  author: string;
  icon?: string;
  license?: string;
  version?: string;
  hooks: Hook[];
  permissions: { files?: "contents"; network: string[] };
  preferences: Preference[];
  verify?: string;
}

export class InvalidManifest extends Error {
  constructor(readonly problems: string[]) {
    super("package.json isn't valid:\n" + problems.map((problem) => `• ${problem}`).join("\n"));
  }
}

const identifier = /^[a-z0-9]+(-[a-z0-9]+)*$/;
const hostName = /^[a-z0-9]([a-z0-9-]*[a-z0-9])?(\.[a-z0-9]([a-z0-9-]*[a-z0-9])?)+$/;
const events: HookEvent[] = ["beforeStart", "afterFinish"];
const preferenceTypes = ["textfield", "password", "checkbox", "dropdown"] as const;

export const isIdentifier = (text: string) => text.length <= 64 && identifier.test(text);

export function readManifest(folder: string): Manifest {
  let json: unknown;
  try {
    json = JSON.parse(readFileSync(join(folder, "package.json"), "utf8"));
  } catch (error) {
    throw new InvalidManifest([`package.json couldn't be read: ${(error as Error).message}`]);
  }
  return validateManifest(json);
}

export function validateManifest(json: unknown): Manifest {
  if (typeof json !== "object" || json === null || Array.isArray(json)) {
    throw new InvalidManifest(["package.json isn't a JSON object."]);
  }
  const root = json as Record<string, any>;
  const problems: string[] = [];
  const text = (key: string, required = true): string | undefined => {
    const value = typeof root[key] === "string" ? root[key].trim() : undefined;
    if (required && !value) problems.push(`“${key}” is missing.`);
    return value || undefined;
  };

  const name = text("name") ?? "";
  if (name && !isIdentifier(name)) {
    problems.push("“name” must be lowercase letters, digits and hyphens, such as “fake-download-check”.");
  }
  const manifest: Manifest = {
    name,
    title: text("title") ?? "",
    description: text("description") ?? "",
    author: text("author") ?? "",
    icon: text("icon", false),
    license: text("license", false),
    version: text("version", false),
    verify: text("verify", false),
    hooks: [],
    permissions: { network: [] },
    preferences: [],
  };
  if (manifest.verify && !isIdentifier(manifest.verify)) {
    problems.push("“verify” must name a file in src, such as “verify”.");
  }

  const hooks: unknown[] = Array.isArray(root.hooks) ? root.hooks : [];
  if (hooks.length === 0) problems.push("“hooks” must list at least one hook.");
  hooks.forEach((entry: any, index) => {
    const label = `hooks[${index}]`;
    if (typeof entry?.name !== "string" || !isIdentifier(entry.name)) {
      problems.push(`${label} needs a “name” of lowercase letters, digits and hyphens.`);
      return;
    }
    if (!events.includes(entry.event)) {
      problems.push(`${label} (“${entry.name}”) needs an “event”: “beforeStart” or “afterFinish”.`);
      return;
    }
    if (manifest.hooks.some((hook) => hook.name === entry.name)) problems.push(`Two hooks are named “${entry.name}”.`);
    manifest.hooks.push({
      name: entry.name,
      title: typeof entry.title === "string" ? entry.title : entry.name,
      description: typeof entry.description === "string" ? entry.description : undefined,
      event: entry.event,
    });
  });

  const permissions = root.permissions;
  if (permissions !== undefined && permissions !== null) {
    if (permissions.files !== undefined) {
      if (permissions.files === "contents") manifest.permissions.files = "contents";
      else if (permissions.files !== "names") problems.push("“permissions.files” can only be “contents”.");
    }
    for (const host of Array.isArray(permissions.network) ? permissions.network : []) {
      const lowered = typeof host === "string" ? host.toLowerCase() : "";
      if (!(lowered.length <= 253 && hostName.test(lowered))) {
        problems.push("“permissions.network” lists host names only, such as “www.virustotal.com”, without https:// or a path.");
        continue;
      }
      if (!manifest.permissions.network.includes(lowered)) manifest.permissions.network.push(lowered);
    }
  }

  const preferences: unknown[] = Array.isArray(root.preferences) ? root.preferences : [];
  preferences.forEach((entry: any, index) => {
    const label = `preferences[${index}]`;
    if (typeof entry?.name !== "string" || !/^[A-Za-z][A-Za-z0-9_]*$/.test(entry.name)) {
      problems.push(`${label} needs a “name” made of letters, digits and underscores, starting with a letter.`);
      return;
    }
    if (!preferenceTypes.includes(entry.type)) {
      problems.push(`${label} (“${entry.name}”) needs a “type”: textfield, password, checkbox or dropdown.`);
      return;
    }
    if (manifest.preferences.some((preference) => preference.name === entry.name)) {
      problems.push(`Two preferences are named “${entry.name}”.`);
    }
    const data = (Array.isArray(entry.data) ? entry.data : [])
      .filter((option: any) => typeof option?.value === "string")
      .map((option: any) => ({ title: typeof option.title === "string" ? option.title : option.value, value: option.value }));
    if (entry.type === "dropdown" && data.length === 0) {
      problems.push(`The dropdown “${entry.name}” needs “data”: a list of { title, value }.`);
    }
    const fallback = entry.default;
    if (fallback !== undefined && fallback !== null) {
      if (entry.type === "checkbox" && typeof fallback !== "boolean") {
        problems.push(`The checkbox “${entry.name}” needs true or false as its default.`);
      } else if (entry.type === "dropdown" && !data.some((option: { value: string }) => option.value === fallback)) {
        problems.push(`The dropdown “${entry.name}” has a default that isn't one of its values.`);
      } else if (entry.type === "textfield" && typeof fallback !== "string") {
        problems.push(`The text field “${entry.name}” needs text as its default.`);
      } else if (entry.type === "password") {
        problems.push(`The password “${entry.name}” can't have a default.`);
      }
    }
    manifest.preferences.push({
      name: entry.name,
      type: entry.type,
      title: typeof entry.title === "string" ? entry.title : entry.name,
      description: typeof entry.description === "string" ? entry.description : undefined,
      required: entry.required === true,
      placeholder: typeof entry.placeholder === "string" ? entry.placeholder : undefined,
      label: typeof entry.label === "string" ? entry.label : undefined,
      default: fallback === null ? undefined : fallback,
      data: data.length > 0 ? data : undefined,
    });
  });

  if (problems.length > 0) throw new InvalidManifest(problems);
  return manifest;
}

/** The manifest OrbTorrent reads, written to dist/package.json. */
export function builtManifest(manifest: Manifest, apiVersion: string): Record<string, unknown> {
  const permissions: Record<string, unknown> = {};
  if (manifest.permissions.files) permissions.files = manifest.permissions.files;
  if (manifest.permissions.network.length > 0) permissions.network = manifest.permissions.network;
  return {
    name: manifest.name,
    title: manifest.title,
    description: manifest.description,
    author: manifest.author,
    ...(manifest.icon && { icon: manifest.icon }),
    ...(manifest.license && { license: manifest.license }),
    ...(manifest.version && { version: manifest.version }),
    hooks: manifest.hooks,
    permissions,
    preferences: manifest.preferences,
    ...(manifest.verify && { verify: manifest.verify }),
    orbtorrent: { api: apiVersion },
  };
}

/** Types for `getPreferenceValues`, written to orb-env.d.ts. */
export function environmentDeclarations(manifest: Manifest): string {
  const lines = manifest.preferences.map((preference) => {
    let type: string;
    switch (preference.type) {
      case "checkbox":
        type = "boolean";
        break;
      case "dropdown":
        type = (preference.data ?? []).map((option) => JSON.stringify(option.value)).join(" | ") || "string";
        break;
      default:
        type = "string";
    }
    const doc = preference.description ? `    /** ${preference.description.replace(/\*\//g, "* /")} */\n` : "";
    return `${doc}    ${preference.name}: ${type};`;
  });
  return [
    "// Generated by `orb build` from package.json. Don't edit: change package.json instead.",
    "",
    "declare global {",
    "  interface OrbPreferences {",
    ...lines,
    "  }",
    "}",
    "",
    "export {};",
    "",
  ].join("\n");
}

/**
 * Every setting has a value when the extension runs: what the user chose, or
 * its default, or else empty text, false, or a dropdown's first option.
 */
export function defaultPreferences(manifest: Manifest): Record<string, unknown> {
  return Object.fromEntries(manifest.preferences.map((preference) => {
    if (preference.default !== undefined) return [preference.name, preference.default];
    switch (preference.type) {
      case "checkbox": return [preference.name, false];
      case "dropdown": return [preference.name, preference.data?.[0]?.value ?? ""];
      default: return [preference.name, ""];
    }
  }));
}
