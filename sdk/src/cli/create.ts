import { cpSync, existsSync, readdirSync, readFileSync, renameSync, statSync, writeFileSync } from "node:fs";
import { join, relative, resolve } from "node:path";
import { isIdentifier } from "./manifest.js";
import { CommandError } from "./output.js";
import { sdkRoot, sdkVersion } from "./paths.js";

export const templates = ["before-start", "after-finish"] as const;
export type Template = (typeof templates)[number];

const textFiles = new Set([".ts", ".json", ".md", ".js", ".gitignore"]);

function titleCase(name: string): string {
  return name.split("-").map((word) => word.charAt(0).toUpperCase() + word.slice(1)).join(" ");
}

/** How the new extension depends on this package: from npm once it's published, otherwise from this folder. */
function apiDependency(): string {
  return sdkRoot.includes(`${"/"}node_modules${"/"}`) ? `^${sdkVersion}` : `file:${sdkRoot}`;
}

export function createExtension(name: string, options: { template?: string; title?: string; directory?: string }): string {
  if (!isIdentifier(name)) {
    throw new CommandError("The name must be lowercase letters, digits and hyphens, such as “plex-mover”.");
  }
  const template = (options.template ?? "before-start") as Template;
  if (!templates.includes(template)) {
    throw new CommandError(`There's no template “${options.template}”.`, [`Use one of: ${templates.join(", ")}.`]);
  }
  const target = resolve(options.directory ?? ".", name);
  if (existsSync(target) && readdirSync(target).length > 0) {
    throw new CommandError(`${relative(process.cwd(), target) || target} already exists and isn't empty.`);
  }
  cpSync(join(sdkRoot, "templates", "_shared"), target, { recursive: true });
  cpSync(join(sdkRoot, "templates", template), target, { recursive: true });

  const replacements: Record<string, string> = {
    "{{name}}": name,
    "{{title}}": options.title ?? titleCase(name),
    "{{api}}": apiDependency(),
  };
  const visit = (folder: string) => {
    for (const entry of readdirSync(folder)) {
      const path = join(folder, entry);
      if (statSync(path).isDirectory()) {
        visit(path);
        continue;
      }
      const extension = entry === "gitignore" ? ".gitignore" : entry.slice(entry.lastIndexOf("."));
      if (!textFiles.has(extension)) continue;
      let text = readFileSync(path, "utf8");
      for (const [token, value] of Object.entries(replacements)) text = text.split(token).join(value);
      writeFileSync(path, text);
    }
  };
  visit(target);
  // npm leaves .gitignore out of published packages, so templates call it gitignore.
  if (existsSync(join(target, "gitignore"))) renameSync(join(target, "gitignore"), join(target, ".gitignore"));
  return target;
}
