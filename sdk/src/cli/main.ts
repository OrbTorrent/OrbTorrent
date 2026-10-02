import { relative, resolve } from "node:path";
import { build } from "./build.js";
import { createExtension, templates } from "./create.js";
import { devCommand, downloadsCommand, runCommand } from "./dev.js";
import { doctorCommand } from "./doctor.js";
import { lintCommand } from "./lint.js";
import { CommandError, printError, printJSON, style } from "./output.js";
import { appName } from "./connection.js";
import { installExtension, packageExtension } from "./package.js";
import { sdkVersion } from "./paths.js";
import { testCommand } from "./test.js";

const help = `orb ${sdkVersion}: build extensions for OrbTorrent

Usage: orb <command> [options]

Commands:
  create <name>        Make a new extension in a new folder
                         --template ${templates.join("|")}   (default before-start)
                         --title "<title>"
  build                Check package.json, type-check and bundle into dist/
  test [files…]        Run the tests in tests/, without OrbTorrent
  lint                 Check the code with ESLint (--fix to fix what it can)
  doctor               Check Node.js, OrbTorrent and this extension, and say what to fix
  dev                  Load into OrbTorrent, rebuild on every save and show logs
  downloads            List your downloads in OrbTorrent, to run a hook on
  run [hook]           Run a hook on one of your downloads in OrbTorrent
                         --download "<name or info hash>"
  install              Package it and ask OrbTorrent to install it, once you confirm
  package              Make <name>.orbext, to install on another Mac

Options:
  --json               Print results as JSON, for scripts and coding agents
  --help, --version

Run commands from the extension's folder. Docs: AGENTS.md in the extension, and
https://orbtorrent.com/docs/extensions`;

interface Arguments {
  positional: string[];
  flags: Record<string, string | true>;
}

function parse(argv: string[]): Arguments {
  const positional: string[] = [];
  const flags: Record<string, string | true> = {};
  const valued = new Set(["template", "title", "download", "dir"]);
  for (let i = 0; i < argv.length; i++) {
    const argument = argv[i];
    if (argument.startsWith("--")) {
      const [name, inline] = argument.slice(2).split("=", 2);
      if (inline !== undefined) flags[name] = inline;
      else if (valued.has(name) && i + 1 < argv.length) flags[name] = argv[++i];
      else flags[name] = true;
    } else if (argument === "-h") {
      flags.help = true;
    } else {
      positional.push(argument);
    }
  }
  return { positional, flags };
}

async function main(): Promise<number> {
  const { positional, flags } = parse(process.argv.slice(2));
  const json = flags.json === true;
  const [command, ...rest] = positional;
  const folder = process.cwd();
  const text = (name: string) => (typeof flags[name] === "string" ? (flags[name] as string) : undefined);

  if (flags.version) {
    console.log(sdkVersion);
    return 0;
  }
  if (!command || flags.help || command === "help") {
    console.log(help);
    return command || flags.help ? 0 : 1;
  }

  try {
    switch (command) {
      case "create": {
        if (!rest[0]) throw new CommandError("Give the new extension a name, such as `orb create plex-mover`.");
        const target = createExtension(rest[0], { template: text("template"), title: text("title"), directory: text("dir") });
        const shown = relative(process.cwd(), target) || ".";
        if (json) {
          printJSON({ ok: true, folder: target });
        } else {
          console.log(`${style.green("✓")} Made ${style.bold(shown)}. Next:\n`);
          console.log(`  cd ${shown}\n  npm install\n  npm test          ${style.dim("# run its tests")}\n  npx orb doctor    ${style.dim("# check OrbTorrent is ready for it")}\n  npm run dev       ${style.dim("# load it into OrbTorrent")}`);
          console.log(`\n${style.dim("AGENTS.md in the folder explains the API, the rules and the loop to follow.")}`);
          console.log(style.dim("Docs: https://orbtorrent.com/docs/extensions/getting-started"));
        }
        return 0;
      }
      case "build": {
        const built = await build(folder);
        if (json) {
          printJSON({ ok: true, name: built.manifest.name, dist: built.dist, hooks: Object.keys(built.hooks), warnings: built.warnings });
        } else {
          for (const warning of built.warnings) console.log(style.yellow(`! ${warning}`));
          console.log(`${style.green("✓")} Built ${style.bold(built.manifest.title)} into ${relative(folder, built.dist)}/ (${Object.keys(built.hooks).length} ${Object.keys(built.hooks).length === 1 ? "hook" : "hooks"})`);
        }
        return 0;
      }
      case "test":
        return (await testCommand(folder, rest, json)) ? 0 : 1;
      case "dev":
        await devCommand(folder);
        return 0;
      case "run":
        return (await runCommand(folder, rest[0], text("download"), json)) ? 0 : 1;
      case "doctor":
        return (await doctorCommand(folder, json)) ? 0 : 1;
      case "downloads":
        return (await downloadsCommand(json)) ? 0 : 1;
      case "install": {
        const { archive, installed } = await installExtension(folder, () => {
          if (!json) console.log(style.dim(`Waiting for you to confirm the install in ${appName}…`));
        });
        const file = relative(folder, archive);
        if (json) {
          printJSON(installed
            ? { ok: true, installed: true, file: archive, app: appName }
            : { ok: true, installed: false, file: archive, app: appName, next: `${appName} asks the user to install it. \`orb doctor\` shows when it's installed.` });
        } else if (installed) {
          console.log(`${style.green("✓")} Installed it in ${appName}.`);
        } else {
          console.log(`${style.green("✓")} Opened ${file} in ${appName}, which asks you to install it.`);
        }
        return 0;
      }
      case "lint":
        return (await lintCommand(folder, { fix: flags.fix === true, json })) ? 0 : 1;
      case "package": {
        const archive = await packageExtension(folder);
        if (json) printJSON({ ok: true, file: archive });
        else console.log(`${style.green("✓")} Made ${relative(folder, archive)}. Open it on a Mac with OrbTorrent to install it.`);
        return 0;
      }
      default:
        throw new CommandError(`There's no command “${command}”.`, ["Run `orb --help` to see them."]);
    }
  } catch (error) {
    printError(error, json);
    if (!(error instanceof CommandError) && !json && error instanceof Error && error.stack) {
      console.error(style.dim(error.stack));
    }
    return 1;
  }
}

process.exitCode = await main();
