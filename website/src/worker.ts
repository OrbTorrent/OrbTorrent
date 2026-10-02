// The Worker in front of orbtorrent.com. Every page is built ahead of time
// and served as a file; this only answers /download/mac, which goes to the
// newest disk image in the update feed, so the download button never needs
// editing (until a release is in the feed, it goes to the releases page on
// GitHub), and the email sign-up's posts (src/lib/newsletter.ts).

import confirmEmail from "../emails/dist/confirm.json";
import { answer, forgetUnconfirmed, type Database, type Newsletter } from "./lib/newsletter";
import { parseFeed } from "./lib/release";
import { site } from "./lib/site";

interface Env {
  /** The built site, from wrangler.jsonc's assets. */
  ASSETS: { fetch(request: Request): Promise<Response> };
  /** Downloads, counted by where they started; stats.sh reads them. */
  DOWNLOADS?: { writeDataPoint(point: { indexes?: string[]; blobs?: string[]; doubles?: number[] }): void };
  /** The email sign-up's list. */
  DB: Database;
  /** Cloudflare Email Service, which may send only as hello@orbtorrent.com. */
  EMAIL: {
    send(message: {
      from: { email: string; name: string };
      to: string;
      subject: string;
      html: string;
      text: string;
      headers?: Record<string, string>;
    }): Promise<{ messageId: string }>;
  };
  /** Five sign-ups a minute from one visitor. */
  SIGNUPS: { limit(options: { key: string }): Promise<{ success: boolean }> };
}

function newsletter(env: Env): Newsletter {
  return {
    db: env.DB,
    origin: site.url,
    async sendConfirmation(to, link) {
      await env.EMAIL.send({
        from: { email: "hello@orbtorrent.com", name: "OrbTorrent" },
        to,
        subject: "Confirm your email for OrbTorrent",
        html: confirmEmail.html.replaceAll("{{link}}", link.replaceAll("&", "&amp;")),
        text: confirmEmail.text.replaceAll("{{link}}", link),
        // Sent by the site, not a person, so auto-replies stay quiet.
        headers: { "Auto-Submitted": "auto-generated" },
      });
    },
    async allow(visitor) {
      return visitor ? (await env.SIGNUPS.limit({ key: visitor })).success : true;
    },
  };
}

async function newestDiskImage(): Promise<{ url: string; version: string }> {
  try {
    const response = await fetch("https://updates.orbtorrent.com/appcast.xml", {
      // Cloudflare keeps the feed for five minutes, so a busy launch day reads it rarely.
      cf: { cacheTtl: 300, cacheEverything: true },
    } as RequestInit);
    const release = response.ok ? parseFeed(await response.text()) : null;
    if (release) return { url: release.url, version: release.version };
  } catch {
    // The releases page is always a good answer.
  }
  return { url: site.releases, version: "" };
}

/**
 * Counts a download by where it started: the page of this site, or the other
 * site that linked here, and the country it came from. Not the address it came
 * from, and not robots following links.
 */
function count(request: Request, env: Env, version: string) {
  const agent = request.headers.get("User-Agent") ?? "";
  const purpose = `${request.headers.get("Sec-Purpose") ?? ""} ${request.headers.get("Purpose") ?? ""}`;
  const mode = request.headers.get("Sec-Fetch-Mode");
  // Only a click or a typed address: not a prefetch, or a page's script fetching it.
  if (request.method !== "GET" || purpose.includes("prefetch") || (mode && mode !== "navigate")) return;
  if (!agent.startsWith("Mozilla/") || /bot|crawl|spider|slurp|preview|headless|lighthouse/i.test(agent)) return;
  let from = "";
  try {
    const referrer = new URL(request.headers.get("Referer") ?? "");
    from = referrer.host === new URL(request.url).host ? referrer.pathname.replace(/\.html$/, "") : referrer.hostname;
  } catch {
    // Typed, bookmarked, or the other site keeps itself to itself.
  }
  const country = (request as { cf?: { country?: string } }).cf?.country ?? "";
  env.DOWNLOADS?.writeDataPoint({ indexes: ["mac"], blobs: [from, version, country], doubles: [1] });
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    if (new URL(request.url).pathname === site.download) {
      const { url, version } = await newestDiskImage();
      count(request, env, version);
      return new Response(null, {
        status: 302,
        // Five minutes, so a second click soon after isn't counted twice.
        headers: { Location: url, "Cache-Control": "private, max-age=300" },
      });
    }
    const signUp = await answer(request, newsletter(env));
    if (signUp) return signUp;
    // Anything else that isn't a file: the not-found page.
    return env.ASSETS.fetch(request);
  },

  /** Each day: forgets the sign-ups no one confirmed within 7 days. */
  async scheduled(_controller: unknown, env: Env): Promise<void> {
    await forgetUnconfirmed(env.DB);
  },
};
