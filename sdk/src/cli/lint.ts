import { existsSync } from "node:fs";
import { join } from "node:path";
import { ESLint } from "eslint";
import { printJSON } from "./output.js";
import { sdkRoot } from "./paths.js";

/** ESLint with OrbTorrent's rules, unless the extension has its own configuration. */
export async function lintCommand(folder: string, options: { fix: boolean; json: boolean }): Promise<boolean> {
  const ownConfig = ["eslint.config.js", "eslint.config.mjs", "eslint.config.ts"].some((name) => existsSync(join(folder, name)));
  const eslint = new ESLint({
    cwd: folder,
    fix: options.fix,
    overrideConfigFile: ownConfig ? undefined : join(sdkRoot, "eslint.config.js"),
  });
  const results = await eslint.lintFiles(["src"]);
  if (options.fix) await ESLint.outputFixes(results);
  const errors = results.reduce((sum, result) => sum + result.errorCount, 0);
  const warnings = results.reduce((sum, result) => sum + result.warningCount, 0);
  if (options.json) {
    printJSON({
      ok: errors === 0,
      errors,
      warnings,
      problems: results.flatMap((result) => result.messages.map((message) => ({
        file: result.filePath.slice(folder.length + 1), line: message.line, column: message.column,
        severity: message.severity === 2 ? "error" : "warning", rule: message.ruleId, message: message.message,
      }))),
    });
  } else {
    const formatter = await eslint.loadFormatter("stylish");
    const text = await formatter.format(results);
    process.stdout.write(text || "No problems found.\n");
  }
  return errors === 0;
}
