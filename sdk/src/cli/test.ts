import { existsSync, readdirSync, readFileSync } from "node:fs";
import { basename, join, relative, resolve } from "node:path";
import { BuildResult, build } from "./build.js";
import { defaultPreferences } from "./manifest.js";
import { FetchMock, HarnessRun, asShown, runInHarness } from "./harness.js";
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
    /** `isNew` is true unless it says otherwise, once the download has finished. */
    files?: { path: string; size?: number; wanted?: boolean; sha256?: string; isNew?: boolean }[];
    /** Other files already next to the download's, relative to its folder, which `files.save` won't replace. */
    alsoOnDisk?: string[];
    /** For an afterChecks hook: other extensions' results. Their files can be named by `path` alone. */
    checks?: Record<string, any>[];
    /** For an afterChecks hook: a check is holding it, rather than it having finished. */
    held?: boolean;
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
  /** Paths of files it should have added with `files.save`, in any order. `*` matches any text. */
  saved?: string[];
  /** Part of the text of each file it added. */
  savedIncludes?: string;
  /** Whether the result asks to be a notification. */
  notify?: boolean;
  /** What it should find about files: a path (`*` matches any text) and its status, or "none" for no result. */
  files?: Record<string, "passed" | "warning" | "failed" | "none">;
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
  saved: { path: string; size: number }[];
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
  if (!outcome.ok) return [outcome.invalid ? `its result can't be shown: ${outcome.message}` : `it threw: ${outcome.message}`];
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
  for (const pattern of expectation.saved ?? []) {
    if (!run.saved.some((saved) => matchesURL(pattern, saved.path))) {
      failures.push(`expected it to add ${pattern}${run.saved.length > 0 ? `, but it added ${run.saved.map((saved) => saved.path).join(", ")}` : ", but it added nothing"}`);
    }
  }
  if (expectation.savedIncludes !== undefined) {
    if (run.saved.length === 0) failures.push(`expected the files it added to include “${expectation.savedIncludes}”, but it added nothing`);
    for (const saved of run.saved) {
      if (!saved.text?.includes(expectation.savedIncludes)) failures.push(`expected ${saved.path} to include “${expectation.savedIncludes}”`);
    }
  }
  const fileResults = Array.isArray(value.files) ? value.files as { path: string; status: string }[] : [];
  for (const [pattern, expected] of Object.entries(expectation.files ?? {})) {
    const found = fileResults.filter((file) => matchesURL(pattern, file.path));
    if (expected === "none") {
      if (found.length > 0) failures.push(`expected no result for ${pattern}, got “${found[0].status}”`);
    } else if (found.length === 0) {
      failures.push(`expected ${pattern} to be “${expected}”, but the result says nothing about it`);
    } else if (found.some((file) => file.status !== expected)) {
      failures.push(`expected ${pattern} to be “${expected}”, got “${found.find((file) => file.status !== expected)!.status}”`);
    }
  }
  if (expectation.notify !== undefined && (value.notify === true) !== expectation.notify) {
    failures.push(expectation.notify ? "expected the result to ask for a notification (notify: true)" : "expected the result not to ask for a notification");
  }
  if (expectation.not) {
    const inner = check(expectation.not, run);
    if (inner.length === 0) failures.push(`expected not ${JSON.stringify(expectation.not)}, but it matched`);
  }
  return failures;
}

/** Another extension's result, as a test gives it, filled in the way OrbTorrent sends it. */
function checkResult(check: Record<string, any>, files: { index: number; path: string }[]): Record<string, unknown> {
  return {
    extension: { name: "another-extension", title: "Another Extension" },
    hook: "check",
    event: "afterFinish",
    ...check,
    ...(Array.isArray(check.files) && {
      files: check.files.map((file: Record<string, any>) => {
        const match = files.find((candidate) => candidate.index === file.index || candidate.path === file.path);
        return { ...file, index: match?.index ?? file.index, path: match?.path ?? file.path };
      }),
    }),
  };
}

async function runTest(path: string, built: BuildResult): Promise<TestReport> {
  const relativePath = relative(built.folder, path);
  let test: TestFile;
  try {
    test = JSON.parse(readFileSync(path, "utf8"));
  } catch (error) {
    return { file: relativePath, name: basename(path), passed: false, failures: [`couldn't be read: ${(error as Error).message}`], logs: [], fetched: [], saved: [] };
  }
  const name = test.name ?? basename(path, ".json");
  const fail = (failure: string): TestReport => ({ file: relativePath, name, passed: false, failures: [failure], logs: [], fetched: [], saved: [] });
  const { manifest } = built;

  let script: string;
  let args: unknown[];
  let entryPoint: Parameters<typeof runInHarness>[2]["entryPoint"];
  const files = (test.download?.files ?? []).map((file, index) => ({
    index, path: file.path, size: file.size ?? 0, wanted: file.wanted ?? true, sha256: file.sha256, isNew: file.isNew,
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
    // As OrbTorrent gives it: once it's finished, which files are new, and
    // for a report on the checks, what they found.
    const finished = hook.event === "afterFinish" || (hook.event === "afterChecks" && !test.download?.held);
    args = [{
      id: test.download?.id ?? "0123456789abcdef0123456789abcdef01234567",
      name: test.download?.name ?? "Download",
      size: files.filter((file) => file.wanted).reduce((sum, file) => sum + file.size, 0),
      isPrivate: test.download?.isPrivate ?? false,
      files: files.map(({ sha256: _, isNew, ...file }) => (finished ? { ...file, isNew: file.wanted && (isNew ?? true) } : file)),
      ...(hook.event === "afterChecks" && {
        checks: (test.download?.checks ?? []).map((check) => checkResult(check, files)),
        isHeld: test.download?.held ?? false,
      }),
    }];
  }

  function preferencesFor(test: TestFile): Record<string, unknown> {
    return { ...defaultPreferences(manifest), ...test.preferences };
  }

  const harnessFiles = Object.fromEntries(files.map((file) => [file.index, { path: file.path, wanted: file.wanted, sha256: file.sha256 }]));
  const run = await runInHarness(script, args, {
    manifest,
    entryPoint,
    held: test.download?.held,
    preferences: preferencesFor(test),
    fetchMocks: test.mocks?.fetch ?? [],
    files: harnessFiles,
    alsoOnDisk: test.download?.alsoOnDisk,
    storage: test.storage ?? {},
    timeout: test.timeout ?? 10_000,
  });
  // The result as OrbTorrent would show it.
  if (entryPoint.type === "hook" && run.outcome.ok) {
    const shown = asShown(run.outcome.value, harnessFiles);
    if ("problem" in shown) {
      run.outcome = { ok: false, message: shown.problem, stack: "", invalid: true };
    } else {
      run.outcome = { ok: true, value: shown.result };
      if (shown.warning) run.logs.push({ level: "warn", message: shown.warning });
    }
  }
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
    saved: run.saved.map(({ path, size }) => ({ path, size })),
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
