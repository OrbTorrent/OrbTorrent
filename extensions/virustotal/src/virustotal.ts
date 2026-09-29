import { DownloadFile, Response, fetch, files, progress, sleep } from "@orbtorrent/api";

// A small client for VirusTotal's API (v3), paced for the free key: 4 requests
// a minute and 500 a day.

const base = "https://www.virustotal.com/api/v3";
/** A little over 15 s, so 4 a minute never trips the limit. */
const gap = 15_500;

export interface Stats {
  malicious: number;
  suspicious: number;
  /** Engines that gave an answer. */
  total: number;
}

export type Lookup = { kind: "found"; stats: Stats } | { kind: "unknown" };

export class VirusTotalError extends Error {
  constructor(readonly reason: "key" | "limit" | "network", message: string) {
    super(message);
  }
}

export const reportURL = (sha256: string) => `https://www.virustotal.com/gui/file/${sha256}`;

function statsOf(raw: Record<string, number> | undefined): Stats {
  const count = (key: string) => (typeof raw?.[key] === "number" ? raw[key] : 0);
  const malicious = count("malicious");
  const suspicious = count("suspicious");
  return { malicious, suspicious, total: malicious + suspicious + count("undetected") + count("harmless") };
}

export class VirusTotal {
  private last = -Infinity;

  constructor(private readonly key: string) {}

  private async pace(): Promise<void> {
    const wait = this.last + gap - Date.now();
    if (wait > 0) await sleep(wait);
    this.last = Date.now();
  }

  async request(path: string, init: { method?: "GET" | "POST"; body?: ReturnType<typeof files.formData> } = {}): Promise<Response> {
    for (let attempt = 0; ; attempt++) {
      await this.pace();
      let response: Response;
      try {
        response = await fetch(base + path, { ...init, headers: { "x-apikey": this.key, accept: "application/json" } });
      } catch (error) {
        if (attempt === 0) continue;
        throw new VirusTotalError("network", `Couldn't reach VirusTotal: ${(error as Error).message}`);
      }
      if (response.status === 401 || response.status === 403) {
        throw new VirusTotalError("key", "VirusTotal didn't accept the API key");
      }
      if (response.status === 429) {
        // Another app using the same key can trip the per-minute limit; a
        // second refusal after a minute means the daily limit.
        if (attempt === 0) {
          await progress({ message: "Waiting a minute for VirusTotal's rate limit…" });
          await sleep(60_000);
          continue;
        }
        throw new VirusTotalError("limit", "VirusTotal's daily limit was reached");
      }
      return response;
    }
  }

  /** What VirusTotal knows about a file, by its fingerprint. */
  async lookup(sha256: string): Promise<Lookup> {
    const response = await this.request(`/files/${sha256}`);
    if (response.status === 404) return { kind: "unknown" };
    if (!response.ok) throw new VirusTotalError("network", `VirusTotal answered with status ${response.status}`);
    const body = await response.json();
    return { kind: "found", stats: statsOf(body?.data?.attributes?.last_analysis_stats) };
  }

  /** Uploads a file and waits up to about five minutes for its analysis. */
  async upload(file: DownloadFile): Promise<Lookup> {
    const response = await this.request("/files", { method: "POST", body: files.formData({ file }) });
    if (!response.ok) throw new VirusTotalError("network", `VirusTotal didn't take the upload (status ${response.status})`);
    const id: string | undefined = (await response.json())?.data?.id;
    if (!id) return { kind: "unknown" };
    for (let poll = 0; poll < 20; poll++) {
      const analysis = await this.request(`/analyses/${encodeURIComponent(id)}`);
      const attributes = (await analysis.json())?.data?.attributes;
      if (attributes?.status === "completed") return { kind: "found", stats: statsOf(attributes.stats) };
    }
    return { kind: "unknown" };
  }
}
