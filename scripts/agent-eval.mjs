#!/usr/bin/env node
// Asks coding agents to build OrbTorrent extensions the way the Develop tab's
// "Build with AI" does, then checks what they made: its tests, build and lint
// pass, its hook runs at the right moment, it has tests that pass a good
// download, and it asks for no more than it needs.
//
//   node scripts/agent-eval.mjs                      every agent found, every request
//   node scripts/agent-eval.mjs --agent claude       one agent (claude, codex, cursor)
//   node scripts/agent-eval.mjs --request discord    one request
//
// Each run starts in an empty folder outside this repository, with the
// extension SDK from npm, as a stranger's would. The agents are told to skip
// the steps that need OrbTorrent (doctor, run and install), and run with
// ORB_APP=dev, so nothing can reach the OrbTorrent in daily use. The runs,
// their logs and results.json stay in the folder printed at the end.
import { spawn, spawnSync } from "node:child_process";
import { existsSync, mkdtempSync, readdirSync, readFileSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

const root = join(import.meta.dirname, "..");
const template = readFileSync(join(root, "OrbTorrent", "Resources", "AgentPrompt.txt"), "utf8");
const minutes = 20;

const requests = [
  {
    id: "scr",
    request: "Hold downloads that contain Windows screensaver (.scr) files, which are programs in disguise.",
    event: "beforeStart", hosts: [],
  },
  {
    id: "discord",
    request: "Send a message to my Discord channel through a webhook when a download finishes.",
    event: "afterFinish", hosts: ["discord.com", "discordapp.com"],
  },
  {
    id: "tiny-film",
    request: "Warn when a film is smaller than a size I choose, 700 MB unless I change it.",
    event: "beforeStart", hosts: [], setting: true,
  },
];

const agents = {
  claude: (prompt) => ["claude", ["-p", prompt, "--dangerously-skip-permissions"]],
  codex: (prompt, folder) => ["codex", ["exec", "--dangerously-bypass-approvals-and-sandbox", "--skip-git-repo-check", "-C", folder, prompt]],
  cursor: (prompt) => ["cursor-agent", ["-p", "--force", "--trust", "--output-format", "text", prompt]],
};

const option = (name) => {
  const index = process.argv.indexOf(`--${name}`);
  return index >= 0 ? process.argv[index + 1] : undefined;
};
const found = (command) => spawnSync("/usr/bin/which", [command]).status === 0;
const chosenAgents = Object.keys(agents).filter((name) => (!option("agent") || name === option("agent")) && found(agents[name]("")[0]));
const chosenRequests = requests.filter((item) => !option("request") || item.id === option("request"));
if (chosenAgents.length === 0 || chosenRequests.length === 0) {
  console.error("No agent or request to run. Agents: claude, codex, cursor (each must be installed). Requests: " + requests.map((item) => item.id).join(", "));
  process.exit(64);
}

function promptFor(request) {
  return template.replace("{{app}}", "").replace("{{request}}", request).trim()
    + "\n\nThis is an automated test on a Mac without OrbTorrent: do steps 1 and 2, skip steps 3 to 5, and stop once the tests, build and lint pass.";
}

function runAgent(agent, prompt, folder, log) {
  const [command, args] = agents[agent](prompt, folder);
  return new Promise((resolve) => {
    const started = Date.now();
    const child = spawn(command, args, { cwd: folder, env: { ...process.env, ORB_APP: "dev" }, stdio: ["ignore", "pipe", "pipe"] });
    let output = "";
    child.stdout.on("data", (chunk) => { output += chunk; });
    child.stderr.on("data", (chunk) => { output += chunk; });
    const timer = setTimeout(() => child.kill("SIGTERM"), minutes * 60_000);
    child.on("close", (code) => {
      clearTimeout(timer);
      writeFileSync(log, output);
      resolve({ code, seconds: Math.round((Date.now() - started) / 1000) });
    });
  });
}

/** The extension the agent made: the folder under `folder` whose package.json has hooks. */
function findExtension(folder) {
  for (const entry of [".", ...readdirSync(folder)]) {
    const candidate = join(folder, entry);
    try {
      const manifest = JSON.parse(readFileSync(join(candidate, "package.json"), "utf8"));
      if (Array.isArray(manifest.hooks)) return { folder: candidate, manifest };
    } catch {
      // Not an extension.
    }
  }
  return undefined;
}

function orb(command, folder) {
  const result = spawnSync("npx", ["--no-install", "orb", command, "--json"], { cwd: folder, encoding: "utf8", env: { ...process.env, ORB_APP: "dev" } });
  try {
    return JSON.parse(result.stdout).ok === true;
  } catch {
    return false;
  }
}

function score(item, folder) {
  const made = findExtension(folder);
  if (!made) return { made: false };
  const { manifest } = made;
  const network = manifest.permissions?.network ?? [];
  const tests = existsSync(join(made.folder, "tests"))
    ? readdirSync(join(made.folder, "tests")).filter((file) => file.endsWith(".json"))
      .map((file) => JSON.parse(readFileSync(join(made.folder, "tests", file), "utf8")))
    : [];
  return {
    made: true,
    name: manifest.name,
    test: orb("test", made.folder),
    build: orb("build", made.folder),
    lint: orb("lint", made.folder),
    event: manifest.hooks.length > 0 && manifest.hooks.every((hook) => hook.event === item.event),
    permissions: network.every((host) => item.hosts.includes(host)) && (item.hosts.length === 0 || network.length > 0)
      && manifest.permissions?.files === undefined,
    setting: !item.setting || (manifest.preferences ?? []).length > 0,
    tests: tests.length,
    passesAGoodOne: tests.some((test) => test.expect?.status === "passed"),
  };
}

const base = mkdtempSync(join(tmpdir(), "orbtorrent-agent-eval-"));
console.log(`Runs in ${base}\n`);
const results = [];
await Promise.all(chosenAgents.map(async (agent) => {
  for (const item of chosenRequests) {
    const folder = join(base, `${agent}-${item.id}`);
    spawnSync("mkdir", ["-p", folder]);
    const run = await runAgent(agent, promptFor(item.request), folder, join(base, `${agent}-${item.id}.log`));
    const log = join(base, `${agent}-${item.id}.log`);
    const result = { agent, request: item.id, ...run, ...score(item, folder) };
    if (!result.made && /authenticat|log ?in|sign ?in/i.test(readFileSync(log, "utf8"))) result.note = "not signed in";
    results.push(result);
    const passed = ["test", "build", "lint", "event", "permissions", "setting", "passesAGoodOne"].every((key) => result[key]) && result.tests >= 2;
    console.log(`${passed ? "✓" : "✗"} ${agent} · ${item.id} (${result.seconds}s)${result.note ? `: ${result.note}` : ""}`);
  }
}));

writeFileSync(join(base, "results.json"), JSON.stringify(results, null, 2) + "\n");
const mark = (value) => (value ? "✓" : "✗");
console.log("\n| Agent | Request | Made | Tests pass | Builds | Lints | Right moment | Only what it needs | Setting | Tests | Passes a good one | Time |");
console.log("|---|---|---|---|---|---|---|---|---|---|---|---|");
for (const result of results.sort((a, b) => (a.agent + a.request).localeCompare(b.agent + b.request))) {
  console.log(`| ${result.agent} | ${result.request} | ${mark(result.made)} | ${mark(result.test)} | ${mark(result.build)} | ${mark(result.lint)} | ${mark(result.event)} | ${mark(result.permissions)} | ${mark(result.setting)} | ${result.tests ?? 0} | ${mark(result.passesAGoodOne)} | ${Math.round(result.seconds / 60)} min |`);
}
console.log(`\nLogs and extensions: ${base}`);
