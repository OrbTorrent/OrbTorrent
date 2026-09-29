import { existsSync, readdirSync, readFileSync } from "node:fs";
import { basename, join, relative, resolve } from "node:path";
import { BuildResult, build } from "./build.js";
import { defaultPreferences } from "./manifest.js";
import { FetchMock, HarnessRun, runInHarness } from "./harness.js";
import { CommandError, printJSON, style } from "./output.js";

// A test is a JSON file in tests/: a download (or settings, for verify), fake
// answers for the network, and what the hook should return.

interface TestFile {
  name?: string;
  /** The hook to run. Leave out for an extension with one hook. */
  hook?: string;
  /** Runs the settings check instead of a hook. */
  verify?: boolean;
  download?: {
    id?: string;
    name?: string;
    isPrivate?: boolean;
    files?: { path: string; size?: number; wanted?: boolean; sha256?: string }[];
  };
  preferences?: Record<string, unknown>;
  storage?: Record<string, unknown>;
  mocks?: { fetch?: FetchMock[] };
  /** Milliseconds; 10 s unless it says otherwise. */
  timeout?: number;
  expect?: Expectation;
}

interface Expectation {
  status?: string;
  summaryIncludes?: string;
  summaryMatches?: string;
  detailsIncludes?: string;
  /** URLs it should have requested, in any order. `*` matches any text. */
  fetched?: string[];
  /** Part of the error it should throw. */
  throws?: string;
  /** For verify: whether the settings are accepted. */
  ok?: boolean;
  messageIncludes?: string;
  not?: Expectation;
}

export interface TestReport {
  file: string;
  name: string;
  passed: boolean;
  failures: string[];
  result?: unknown;
  error?: string;
  logs: { level: string; message: string }[];
  fetched: { method: string; url: string }[];
}

const matchesURL = (pattern: string, url: string) => {
  if (!pattern.includes("*")) return pattern === url;
  return new RegExp(`^${pattern.split("*").map((part) => part.replace(/[.+?^${}()|[\]\\]/g, "\\$&")).join(".*")}$`).test(url);
};

function check(expectation: Expectation, run: HarnessRun): string[] {
  const failures: string[] = [];
  const outcome = run.outcome;
  if (expectation.throws !== undefined) {
    if (outcome.ok) failures.push(`expected it to throw “${expectation.throws}”, but it returned ${JSON.stringify(outcome.value)}`);
    else if (!outcome.message.includes(expectation.throws)) failures.push(`expected an error including “${expectation.throws}”, got “${outcome.message}”`);
    return failures;
  }
  if (!outcome.ok) return [`it threw: ${outcome.message}`];
  const value = (outcome.value ?? {}) as Record<string, unknown>;
  const summary = typeof value.summary === "string" ? value.summary : "";
  const details = typeof value.details === "string" ? value.details : "";
  const message = typeof value.message === "string" ? value.message : "";
  if (expectation.status !== undefined && value.status !== expectation.status) {
    failures.push(`expected status “${expectation.status}”, got “${String(value.status)}” (${summary || "no summary"})`);
  }
  if (expectation.summaryIncludes !== undefined && !summary.toLowerCase().includes(expectation.summaryIncludes.toLowerCase())) {
    failures.push(`expected the summary to include “${expectation.summaryIncludes}”, got “${summary}”`);
  }
  if (expectation.summaryMatches !== undefined && !new RegExp(expectation.summaryMatches).test(summary)) {
    failures.push(`expected the summary to match /${expectation.summaryMatches}/, got “${summary}”`);
  }
  if (expectation.detailsIncludes !== undefined && !details.includes(expectation.detailsIncludes)) {
    failures.push(`expected the details to include “${expectation.detailsIncludes}”`);
  }
  if (expectation.ok !== undefined && value.ok !== expectation.ok) {
    failures.push(`expected ok to be ${expectation.ok}, got ${String(value.ok)}${message ? ` (“${message}”)` : ""}`);
  }
  if (expectation.messageIncludes !== undefined && !message.includes(expectation.messageIncludes)) {
    failures.push(`expected the message to include “${expectation.messageIncludes}”, got “${message}”`);
  }
  for (const pattern of expectation.fetched ?? []) {
    if (!run.fetched.some((request) => matchesURL(pattern, request.url))) failures.push(`expected a request to ${pattern}`);
  }
  if (expectation.not) {
    const inner = check(expectation.not, run);
    if (inner.length === 0) failures.push(`expected not ${JSON.stringify(expectation.not)}, but it matched`);
  }
  return failures;
}

async function runTest(path: string, built: BuildResult): Promise<TestReport> {
  const relativePath = relative(built.folder, path);
  let test: TestFile;
  try {
    test = JSON.parse(readFileSync(path, "utf8"));
  } catch (error) {
    return { file: relativePath, name: basename(path), passed: false, failures: [`couldn't be read: ${(error as Error).message}`], logs: [], fetched: [] };
  }
  const name = test.name ?? basename(path, ".json");
  const fail = (failure: string): TestReport => ({ file: relativePath, name, passed: false, failures: [failure], logs: [], fetched: [] });
  const { manifest } = built;

  let script: string;
  let args: unknown[];
  let entryPoint: Parameters<typeof runInHarness>[2]["entryPoint"];
  const files = (test.download?.files ?? []).map((file, index) => ({
    index, path: file.path, size: file.size ?? 0, wanted: file.wanted ?? true, sha256: file.sha256,
  }));
  if (test.verify) {
    if (!built.verify) return fail("the extension has no “verify” in package.json");
    script = readFileSync(built.verify, "utf8");
    entryPoint = { type: "verify", name: manifest.verify! };
    args = [preferencesFor(test)];
  } else {
    const hook = test.hook ? manifest.hooks.find((candidate) => candidate.name === test.hook)
      : manifest.hooks.length === 1 ? manifest.hooks[0] : undefined;
    if (!hook) {
      return fail(test.hook ? `package.json has no hook named “${test.hook}”` : `say which hook to run with "hook": ${manifest.hooks.map((h) => `“${h.name}”`).join(" or ")}`);
    }
    script = readFileSync(built.hooks[hook.name], "utf8");
    entryPoint = { type: "hook", name: hook.name, event: hook.event };
    args = [{
      id: test.download?.id ?? "0123456789abcdef0123456789abcdef01234567",
      name: test.download?.name ?? "Download",
      size: files.filter((file) => file.wanted).reduce((sum, file) => sum + file.size, 0),
      isPrivate: test.download?.isPrivate ?? false,
      files: files.map(({ sha256: _, ...file }) => file),
    }];
  }

  function preferencesFor(test: TestFile): Record<string, unknown> {
    return { ...defaultPreferences(manifest), ...test.preferences };
  }

  const run = await runInHarness(script, args, {
    manifest,
    entryPoint,
    preferences: preferencesFor(test),
    fetchMocks: test.mocks?.fetch ?? [],
    files: Object.fromEntries(files.map((file) => [file.index, { sha256: file.sha256 }])),
    storage: test.storage ?? {},
    timeout: test.timeout ?? 10_000,
  });
  const failures = test.expect ? check(test.expect, run) : run.outcome.ok ? [] : [`it threw: ${run.outcome.message}`];
  return {
    file: relativePath,
    name,
    passed: failures.length === 0,
    failures,
    result: run.outcome.ok ? run.outcome.value : undefined,
    error: run.outcome.ok ? undefined : run.outcome.message,
    logs: run.logs,
    fetched: run.fetched,
  };
}

export async function testCommand(folder: string, paths: string[], json: boolean): Promise<boolean> {
  const built = await build(folder);
  const testsFolder = join(folder, "tests");
  const files = paths.length > 0
    ? paths.map((path) => resolve(path))
    : existsSync(testsFolder)
      ? readdirSync(testsFolder).filter((name) => name.endsWith(".json")).sort().map((name) => join(testsFolder, name))
      : [];
  if (files.length === 0) {
    throw new CommandError("There are no tests.", ["Add a JSON file to tests/. See AGENTS.md for the format."]);
  }
  const reports: TestReport[] = [];
  for (const file of files) reports.push(await runTest(file, built));
  const passed = reports.filter((report) => report.passed).length;
  const failed = reports.length - passed;

  if (json) {
    printJSON({ ok: failed === 0, passed, failed, tests: reports });
  } else {
    for (const report of reports) {
      console.log(`${report.passed ? style.green("✓") : style.red("✗")} ${report.name} ${style.dim(report.file)}`);
      if (report.passed) continue;
      for (const failure of report.failures) console.log(`    ${style.red(failure)}`);
      if (report.result !== undefined) console.log(style.dim(`    returned ${JSON.stringify(report.result)}`));
      for (const log of report.logs) console.log(style.dim(`    [${log.level}] ${log.message}`));
    }
    console.log(`\n${failed === 0 ? style.green(`${passed} passed`) : `${style.green(`${passed} passed`)}, ${style.red(`${failed} failed`)}`}`);
  }
  return failed === 0;
}
