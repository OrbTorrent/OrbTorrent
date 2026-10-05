import { Download, DownloadFile, FileResult, Result, files, getPreferenceValues, progress, storage } from "@orbtorrent/api";
import { Lookup, Stats, VirusTotal, VirusTotalError, reportURL } from "./virustotal";

const programs = new Set(["exe", "msi", "dll", "scr", "com", "bat", "cmd", "ps1", "vbs", "js", "jar", "lnk", "dmg", "pkg", "app", "command", "sh", "apk", "deb", "rpm", "appimage", "bin"]);
const archives = new Set(["zip", "rar", "7z", "tar", "gz", "tgz", "bz2", "xz", "iso", "img", "cab"]);
const documents = new Set(["pdf", "doc", "docx", "docm", "xls", "xlsx", "xlsm", "ppt", "pptx", "pptm", "rtf", "odt", "ods", "epub", "chm", "html", "htm", "svg"]);

/** Answers kept for a week, and "not known" for a day, so reruns don't use up the limit. */
const cacheKey = "lookups";
const week = 7 * 24 * 60 * 60 * 1000;
const day = 24 * 60 * 60 * 1000;
const cacheSize = 2000;
const uploadLimit = 32_000_000;

interface Cached {
  at: number;
  stats?: Stats;
}

interface Checked {
  file: DownloadFile;
  sha256: string;
  lookup: Lookup;
}

const nameOf = (path: string) => path.split("/").pop() ?? path;
const extensionOf = (path: string) => {
  const name = nameOf(path);
  const dot = name.lastIndexOf(".");
  return dot > 0 ? name.slice(dot + 1).toLowerCase() : "";
};
/** 0 for programs, 1 archives, 2 documents, 3 anything else. */
const risk = (path: string) => {
  const extension = extensionOf(path);
  if (programs.has(extension) || path.split("/").some((part) => part.toLowerCase().endsWith(".app"))) return 0;
  if (archives.has(extension) || /\.(r\d{2}|\d{3})$/i.test(path)) return 1;
  if (documents.has(extension)) return 2;
  return 3;
};
const plural = (count: number, one: string, many = `${one}s`) => `${count} ${count === 1 ? one : many}`;

export default async function scan(download: Download): Promise<Result> {
  const { apiKey, scope, uploadUnknown } = getPreferenceValues();
  const candidates = download.files
    .filter((file) => file.wanted && (scope === "all" || risk(file.path) < 3))
    .sort((a, b) => risk(a.path) - risk(b.path) || a.index - b.index);
  if (candidates.length === 0) {
    return {
      status: "skipped",
      summary: "Nothing to check: no programs, archives or documents",
      details: "To check videos and music too, set **Files to check** to **All files** in the extension's settings.",
    };
  }

  const client = new VirusTotal(apiKey.trim());
  const cache = (await storage.get<Record<string, Cached>>(cacheKey)) ?? {};
  const checked: Checked[] = [];
  let stopped: VirusTotalError | undefined;
  for (const [position, file] of candidates.entries()) {
    const name = nameOf(file.path);
    await progress({ done: position, total: candidates.length, message: `Checking ${name}…` });
    const sha256 = await files.sha256(file);
    const cached = cache[sha256];
    let lookup: Lookup;
    if (cached && Date.now() - cached.at < (cached.stats ? week : day)) {
      lookup = cached.stats ? { kind: "found", stats: cached.stats } : { kind: "unknown" };
    } else if (stopped) {
      // After a limit or an error, only answers it remembers, so files it
      // flagged before, such as before more of the download was chosen, still show.
      continue;
    } else {
      try {
        lookup = await client.lookup(sha256);
        if (lookup.kind === "unknown" && uploadUnknown && file.size <= uploadLimit) {
          await progress({ done: position, total: candidates.length, message: `Uploading ${name} to be scanned…` });
          lookup = await client.upload(file);
        }
      } catch (error) {
        if (!(error instanceof VirusTotalError)) throw error;
        stopped = error;
        continue;
      }
      cache[sha256] = lookup.kind === "found" ? { at: Date.now(), stats: lookup.stats } : { at: Date.now() };
    }
    checked.push({ file, sha256, lookup });
  }
  await progress({ done: checked.length, total: candidates.length });
  const newest = Object.entries(cache).sort(([, a], [, b]) => b.at - a.at).slice(0, cacheSize);
  await storage.set(cacheKey, Object.fromEntries(newest));
  return { ...result(checked, candidates.length, stopped), ...fileResults(checked) };
}

/** Each file VirusTotal knows, shown beside it in OrbTorrent. */
function fileResults(checked: Checked[]): { files?: FileResult[] } {
  const results = checked.flatMap(({ file, sha256, lookup }): FileResult[] => {
    if (lookup.kind !== "found") return [];
    const { malicious, suspicious } = lookup.stats;
    const status = malicious >= 3 ? "failed" : malicious > 0 || suspicious > 0 ? "warning" : "passed";
    return [{ file, status, summary: verdict(lookup.stats), link: { title: "VirusTotal Report", url: reportURL(sha256) } }];
  });
  return results.length > 0 ? { files: results } : {};
}

function result(checked: Checked[], total: number, stopped: VirusTotalError | undefined): Result {
  const found = checked.flatMap((entry) => (entry.lookup.kind === "found" ? [{ ...entry, stats: entry.lookup.stats }] : []));
  const flagged = found
    .filter(({ stats }) => stats.malicious > 0 || stats.suspicious > 0)
    .sort((a, b) => b.stats.malicious - a.stats.malicious || b.stats.suspicious - a.stats.suspicious);
  const unknown = checked.filter((entry) => entry.lookup.kind === "unknown");

  // What VirusTotal said about each file shows beside it, so the details
  // are for files it couldn't say anything about.
  const lines: string[] = [];
  if (unknown.length > 0) {
    const names = unknown.slice(0, 10).map((entry) => `\`${nameOf(entry.file.path)}\``).join(", ");
    lines.push(`- Not known to VirusTotal: ${names}${unknown.length > 10 ? ` and ${unknown.length - 10} more` : ""}. New files often aren't.`);
  }
  if (stopped && checked.length < total) {
    const left = total - checked.length;
    lines.push(`- ${plural(left, "file")} ${left === 1 ? "wasn't" : "weren't"} checked: ${stopped.message}.`);
  }
  const details = lines.length > 0 ? lines.join("\n") : undefined;
  const worst = flagged[0];
  if (worst) {
    const others = flagged.length > 1 ? ` and ${plural(flagged.length - 1, "more file")}` : "";
    const name = nameOf(worst.file.path);
    const link = { title: "Open VirusTotal Report", url: reportURL(worst.sha256) };
    if (worst.stats.malicious >= 3) {
      return { status: "failed", summary: `${worst.stats.malicious} of ${worst.stats.total} engines flag ${name}${others}`, details, link };
    }
    const summary = worst.stats.malicious > 0
      ? `${plural(worst.stats.malicious, "engine")} ${worst.stats.malicious === 1 ? "flags" : "flag"} ${name}${others}`
      : `${plural(worst.stats.suspicious, "engine")} ${worst.stats.suspicious === 1 ? "calls" : "call"} ${name} suspicious${others}`;
    return { status: "warning", summary, details, link };
  }
  if (stopped) {
    if (stopped.reason === "key") {
      return { status: "skipped", summary: "VirusTotal didn't accept the API key. Check it on OrbTorrent's Extensions page", details };
    }
    if (checked.length === 0) return { status: "skipped", summary: `${stopped.message}. Run it again later`, details };
    return { status: "skipped", summary: `Checked ${checked.length} of ${total} files, then ${stopped.message.charAt(0).toLowerCase()}${stopped.message.slice(1)}`, details };
  }
  if (found.length === 0) {
    return { status: "skipped", summary: `VirusTotal hasn't seen ${checked.length === 1 ? "this file" : "these files"}, so it couldn't check ${checked.length === 1 ? "it" : "them"}`, details };
  }
  const unknownNote = unknown.length > 0 ? ` (${unknown.length} not known to VirusTotal)` : "";
  const summary = checked.length === 1 ? `No engine flagged ${nameOf(checked[0].file.path)}` : `No engine flagged these ${checked.length} files${unknownNote}`;
  return { status: "passed", summary, details };
}

/** What the engines said about one file. */
function verdict(stats: Stats): string {
  if (stats.malicious > 0) {
    const suspicious = stats.suspicious > 0 ? `, ${stats.suspicious} suspicious` : "";
    return `${stats.malicious} of ${stats.total} engines call it malicious${suspicious}`;
  }
  if (stats.suspicious > 0) return `${stats.suspicious} of ${stats.total} engines call it suspicious`;
  return `None of ${stats.total} engines flag it`;
}
