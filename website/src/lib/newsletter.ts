// "Hear about big releases", the email sign-up in the site's footer.
//
// The form posts an address to /subscribe. It's kept unconfirmed, and an
// email goes to it with a link to confirm; it joins the list only once that
// link is used, so no one can sign up someone else. Unconfirmed addresses are
// deleted after 7 days, and unsubscribing deletes an address at once. Only
// the address and when it signed up and confirmed are kept, in the D1
// database orbtorrent-newsletter (migrations/).
//
// The Worker answers the three POSTs here. Each step's page is built with the
// site (src/pages/subscribe/, src/pages/unsubscribe*), and the confirm and
// unsubscribe pages post back to themselves, so a mail scanner opening a link
// changes nothing.

/** The part of a D1 database this uses. */
export interface Database {
  prepare(sql: string): Statement;
}
export interface Statement {
  bind(...values: unknown[]): Statement;
  first<T = Record<string, unknown>>(): Promise<T | null>;
  run(): Promise<unknown>;
}

export interface Newsletter {
  db: Database;
  /** Where the links in emails lead: https://orbtorrent.com. */
  origin: string;
  /** Sends the email with the link to confirm. Throws an error with a `code` when it can't. */
  sendConfirmation(to: string, link: string): Promise<void>;
  /** Whether this visitor (their IP address, not kept) may sign up now. */
  allow(visitor: string): Promise<boolean>;
  now?: () => Date;
  token?: () => string;
}

export const pages = {
  check: "/subscribe/check",
  confirmed: "/subscribe/confirmed",
  expired: "/subscribe/expired",
  problem: "/subscribe/problem",
  unsubscribed: "/unsubscribe/done",
};

const minute = 60_000;
const day = 24 * 60 * minute;
/** How long a link to confirm works. */
export const confirmWithin = 7 * day;
/** An address gets another confirmation email no sooner than this. */
const resendAfter = 10 * minute;
/** At most this many confirmation emails a day, however many ask. */
const dailyEmails = 500;

/** Answers a POST to /subscribe, /subscribe/confirm or /unsubscribe; anything else is the site's. */
export async function answer(request: Request, newsletter: Newsletter): Promise<Response | null> {
  if (request.method !== "POST") return null;
  switch (new URL(request.url).pathname) {
    case "/subscribe":
      return subscribe(request, newsletter);
    case "/subscribe/confirm":
      return confirm(request, newsletter);
    case "/unsubscribe":
      return unsubscribe(request, newsletter);
    default:
      return null;
  }
}

/** An address in lower case, or null if it can't be one. */
export function normalise(input: string): string | null {
  const email = input.trim().toLowerCase();
  if (email.length > 254) return null;
  return /^[^\s@<>()[\]\\,;:"]{1,64}@(?:[a-z0-9](?:[a-z0-9-]*[a-z0-9])?\.)+[a-z][a-z0-9-]*[a-z0-9]$/.test(email) ? email : null;
}

async function subscribe(request: Request, newsletter: Newsletter): Promise<Response> {
  const { db } = newsletter;
  const now = (newsletter.now ?? (() => new Date()))();
  const form = await request.formData().catch(() => null);
  // People leave the hidden field empty; bots fill in every field. They're
  // told it worked, and nothing happens.
  if (!form || String(form.get("website") ?? "")) return reply(request, pages.check);
  const email = normalise(String(form.get("email") ?? ""));
  if (!email) return reply(request, pages.problem, "That doesn't look like an email address.", 400);
  if (!(await newsletter.allow(request.headers.get("CF-Connecting-IP") ?? ""))) {
    return reply(request, pages.problem, "That's a lot of tries. Wait a minute, then try again.", 429);
  }

  const row = await db
    .prepare("SELECT sent_at, confirmed_at FROM subscribers WHERE email = ?")
    .bind(email)
    .first<{ sent_at: string | null; confirmed_at: string | null }>();
  // Already on the list, or an email went just now: the same answer as
  // anyone else, so the form never says who's on the list.
  if (row?.confirmed_at) return reply(request, pages.check);
  if (row?.sent_at && now.getTime() - Date.parse(row.sent_at) < resendAfter) return reply(request, pages.check);

  const sent = await db
    .prepare("SELECT COUNT(*) AS emails FROM subscribers WHERE sent_at > ?")
    .bind(new Date(now.getTime() - day).toISOString())
    .first<{ emails: number }>();
  if ((sent?.emails ?? 0) >= dailyEmails) {
    return reply(request, pages.problem, "So many people are signing up that it's paused until tomorrow. Try again then.", 503);
  }

  const token = (newsletter.token ?? randomToken)();
  await db
    .prepare(
      `INSERT INTO subscribers (email, token, signed_up_at, sent_at) VALUES (?1, ?2, ?3, ?3)
       ON CONFLICT (email) DO UPDATE SET token = ?2, sent_at = ?3`,
    )
    .bind(email, token, now.toISOString())
    .run();
  const link = new URL(`/subscribe/confirm?token=${token}`, newsletter.origin).href;
  try {
    await newsletter.sendConfirmation(email, link);
  } catch (error) {
    const code = (error as { code?: string }).code ?? "";
    // It bounced or was reported before, so nothing can reach it.
    if (code === "E_RECIPIENT_SUPPRESSED") return reply(request, pages.check);
    // So they can try again at once. Logged by its code alone, since the
    // message could hold the address.
    await db.prepare("UPDATE subscribers SET sent_at = NULL WHERE email = ?").bind(email).run();
    console.error(`A confirmation email couldn't be sent: ${code || "no code"}`);
    return reply(request, pages.problem, "The email to confirm couldn't be sent. Try again in a few minutes.", 502);
  }
  return reply(request, pages.check);
}

async function confirm(request: Request, newsletter: Newsletter): Promise<Response> {
  const { db } = newsletter;
  const now = (newsletter.now ?? (() => new Date()))();
  const token = tokenOf(request);
  const row = token
    ? await db
        .prepare("SELECT sent_at, confirmed_at FROM subscribers WHERE token = ?")
        .bind(token)
        .first<{ sent_at: string | null; confirmed_at: string | null }>()
    : null;
  if (!row) return reply(request, pages.expired);
  if (!row.confirmed_at) {
    if (!row.sent_at || now.getTime() - Date.parse(row.sent_at) > confirmWithin) {
      await db.prepare("DELETE FROM subscribers WHERE token = ?").bind(token).run();
      return reply(request, pages.expired);
    }
    await db.prepare("UPDATE subscribers SET confirmed_at = ? WHERE token = ?").bind(now.toISOString(), token).run();
  }
  return reply(request, pages.confirmed);
}

async function unsubscribe(request: Request, newsletter: Newsletter): Promise<Response> {
  const token = tokenOf(request);
  if (token) await newsletter.db.prepare("DELETE FROM subscribers WHERE token = ?").bind(token).run();
  // A mail app's own Unsubscribe button (RFC 8058) only needs to hear it worked.
  const body = await request.text().catch(() => "");
  if (body.includes("List-Unsubscribe=One-Click")) return new Response(null, { status: 200 });
  return reply(request, pages.unsubscribed);
}

/** Deletes the addresses no one confirmed within 7 days. The Worker runs it each day. */
export async function forgetUnconfirmed(db: Database, now = new Date()): Promise<void> {
  await db
    .prepare("DELETE FROM subscribers WHERE confirmed_at IS NULL AND COALESCE(sent_at, signed_up_at) < ?")
    .bind(new Date(now.getTime() - confirmWithin).toISOString())
    .run();
}

function tokenOf(request: Request): string {
  const token = new URL(request.url).searchParams.get("token") ?? "";
  return /^[A-Za-z0-9_-]{20,64}$/.test(token) ? token : "";
}

function randomToken(): string {
  const bytes = crypto.getRandomValues(new Uint8Array(24));
  return btoa(String.fromCharCode(...bytes)).replace(/\+/g, "-").replace(/\//g, "_");
}

/**
 * The footer's script asks for JSON and shows the answer where the form was;
 * without it, the form's post goes on to the page for that step.
 */
function reply(request: Request, page: string, problem = "", status = 200): Response {
  if (request.headers.get("Accept")?.includes("application/json")) {
    return Response.json(problem ? { ok: false, message: problem } : { ok: true }, { status });
  }
  return new Response(null, { status: 303, headers: { Location: page } });
}
