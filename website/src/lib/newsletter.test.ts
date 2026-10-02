// The sign-up, run against SQLite with the D1 database's own schema.
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { DatabaseSync } from "node:sqlite";
import { test } from "node:test";
import { answer, forgetUnconfirmed, normalise, pages, type Database, type Newsletter } from "./newsletter.ts";

const schema = readFileSync(new URL("../../migrations/0001_subscribers.sql", import.meta.url), "utf8");
const minute = 60_000;
const day = 24 * 60 * minute;

/** A D1 database, as far as the sign-up uses one. */
function database(): Database & { sqlite: DatabaseSync } {
  const sqlite = new DatabaseSync(":memory:");
  sqlite.exec(schema);
  return {
    sqlite,
    prepare(sql) {
      let values: unknown[] = [];
      const statement = {
        bind(...bound: unknown[]) {
          values = bound;
          return statement;
        },
        async first<T>() {
          return (sqlite.prepare(sql).get(...(values as [])) ?? null) as T | null;
        },
        async run() {
          return sqlite.prepare(sql).run(...(values as []));
        },
      };
      return statement;
    },
  };
}

function setUp(options: { allow?: boolean; fail?: string } = {}) {
  const db = database();
  const sent: { to: string; link: string }[] = [];
  let now = new Date("2026-10-02T09:00:00Z");
  let tokens = 0;
  const newsletter: Newsletter = {
    db,
    origin: "https://orbtorrent.com",
    async sendConfirmation(to, link) {
      if (options.fail) throw Object.assign(new Error("no"), { code: options.fail });
      sent.push({ to, link });
    },
    async allow() {
      return options.allow ?? true;
    },
    now: () => now,
    token: () => `token-${String(++tokens).padStart(20, "0")}`,
  };
  return {
    db,
    sent,
    newsletter,
    later(milliseconds: number) {
      now = new Date(now.getTime() + milliseconds);
    },
    row(email: string) {
      return db.sqlite.prepare("SELECT * FROM subscribers WHERE email = ?").get(email) as Record<string, string | null> | undefined;
    },
  };
}

function signUp(newsletter: Newsletter, fields: Record<string, string>, json = true) {
  return answer(
    new Request("https://orbtorrent.com/subscribe", {
      method: "POST",
      body: new URLSearchParams(fields),
      headers: json ? { Accept: "application/json" } : {},
    }),
    newsletter,
  );
}

function post(newsletter: Newsletter, link: string, body = "") {
  return answer(new Request(link, { method: "POST", body, headers: { "Content-Type": "application/x-www-form-urlencoded" } }), newsletter);
}

test("an address joins the list only once the link in its email is used", async () => {
  const { newsletter, sent, row } = setUp();
  const response = await signUp(newsletter, { email: "  Someone@Example.com ", website: "" });
  assert.equal(response?.status, 200);
  assert.deepEqual(await response?.json(), { ok: true });
  assert.equal(sent.length, 1);
  assert.equal(sent[0].to, "someone@example.com");
  assert.match(sent[0].link, /^https:\/\/orbtorrent\.com\/subscribe\/confirm\?token=token-\d{20}$/);
  assert.equal(row("someone@example.com")?.confirmed_at, null);

  const confirmed = await post(newsletter, sent[0].link);
  assert.equal(confirmed?.status, 303);
  assert.equal(confirmed?.headers.get("Location"), pages.confirmed);
  assert.equal(row("someone@example.com")?.confirmed_at, "2026-10-02T09:00:00.000Z");
  // Using the link again says the same.
  assert.equal((await post(newsletter, sent[0].link))?.headers.get("Location"), pages.confirmed);
});

test("without the footer's script, each step goes to its page", async () => {
  const { newsletter } = setUp();
  const response = await signUp(newsletter, { email: "someone@example.com" }, false);
  assert.equal(response?.status, 303);
  assert.equal(response?.headers.get("Location"), pages.check);
  const wrong = await signUp(newsletter, { email: "not an address" }, false);
  assert.equal(wrong?.headers.get("Location"), pages.problem);
});

test("a bot that fills in the hidden field is told it worked, and nothing happens", async () => {
  const { newsletter, sent, row } = setUp();
  const response = await signUp(newsletter, { email: "someone@example.com", website: "https://spam.example" });
  assert.deepEqual(await response?.json(), { ok: true });
  assert.equal(sent.length, 0);
  assert.equal(row("someone@example.com"), undefined);
});

test("a wrong address, or too many tries, gets a message", async () => {
  const wrong = await signUp(setUp().newsletter, { email: "someone@" });
  assert.equal(wrong?.status, 400);
  assert.equal((await wrong?.json()).ok, false);

  const busy = setUp({ allow: false });
  const limited = await signUp(busy.newsletter, { email: "someone@example.com" });
  assert.equal(limited?.status, 429);
  assert.equal(busy.sent.length, 0);
});

test("signing up again gives the same answer, without saying who's on the list", async () => {
  const { newsletter, sent, later } = setUp();
  await signUp(newsletter, { email: "someone@example.com" });
  // Moments later: no second email.
  assert.deepEqual(await (await signUp(newsletter, { email: "someone@example.com" }))?.json(), { ok: true });
  assert.equal(sent.length, 1);

  // Later, a new email whose link replaces the first.
  later(11 * minute);
  await signUp(newsletter, { email: "someone@example.com" });
  assert.equal(sent.length, 2);
  assert.notEqual(sent[1].link, sent[0].link);
  assert.equal((await post(newsletter, sent[0].link))?.headers.get("Location"), pages.expired);
  await post(newsletter, sent[1].link);

  // Once confirmed, never another email.
  later(day);
  assert.deepEqual(await (await signUp(newsletter, { email: "someone@example.com" }))?.json(), { ok: true });
  assert.equal(sent.length, 2);
});

test("a link to confirm works for 7 days", async () => {
  const { newsletter, sent, later, row } = setUp();
  await signUp(newsletter, { email: "someone@example.com" });
  later(7 * day + minute);
  const response = await post(newsletter, sent[0].link);
  assert.equal(response?.headers.get("Location"), pages.expired);
  assert.equal(row("someone@example.com"), undefined);
  // A made-up link, too.
  const made = await post(newsletter, "https://orbtorrent.com/subscribe/confirm?token=nothing-like-a-real-token");
  assert.equal(made?.headers.get("Location"), pages.expired);
});

test("when the email can't be sent, they can try again at once", async () => {
  const failing = setUp({ fail: "E_DELIVERY_FAILED" });
  const response = await signUp(failing.newsletter, { email: "someone@example.com" });
  assert.equal(response?.status, 502);
  assert.equal(failing.row("someone@example.com")?.sent_at, null);

  // An address that bounced before: nothing can reach it, and it isn't an error.
  const suppressed = setUp({ fail: "E_RECIPIENT_SUPPRESSED" });
  assert.deepEqual(await (await signUp(suppressed.newsletter, { email: "gone@example.com" }))?.json(), { ok: true });
});

test("no more than 500 confirmation emails a day", async () => {
  const { newsletter, db, sent } = setUp();
  const insert = db.sqlite.prepare("INSERT INTO subscribers (email, token, signed_up_at, sent_at) VALUES (?, ?, ?, ?)");
  for (let n = 0; n < 500; n++) {
    insert.run(`person${n}@example.com`, `earlier-token-${String(n).padStart(10, "0")}`, "2026-10-02T08:00:00.000Z", "2026-10-02T08:00:00.000Z");
  }
  const response = await signUp(newsletter, { email: "someone@example.com" });
  assert.equal(response?.status, 503);
  assert.equal(sent.length, 0);
});

test("unsubscribing deletes the address, from the page or a mail app's button", async () => {
  const { newsletter, sent, row } = setUp();
  await signUp(newsletter, { email: "one@example.com" });
  await signUp(newsletter, { email: "two@example.com" });
  await post(newsletter, sent[0].link);
  await post(newsletter, sent[1].link);

  const page = await post(newsletter, sent[0].link.replace("/subscribe/confirm", "/unsubscribe"));
  assert.equal(page?.headers.get("Location"), pages.unsubscribed);
  assert.equal(row("one@example.com"), undefined);

  const oneClick = await post(newsletter, sent[1].link.replace("/subscribe/confirm", "/unsubscribe"), "List-Unsubscribe=One-Click");
  assert.equal(oneClick?.status, 200);
  assert.equal(row("two@example.com"), undefined);
});

test("unconfirmed addresses are forgotten after 7 days; confirmed ones stay", async () => {
  const { newsletter, sent, db, later, row } = setUp();
  await signUp(newsletter, { email: "waiting@example.com" });
  await signUp(newsletter, { email: "joined@example.com" });
  await post(newsletter, sent[1].link);
  await forgetUnconfirmed(db, new Date("2026-10-08T09:00:00Z"));
  assert.ok(row("waiting@example.com"));
  later(8 * day);
  await forgetUnconfirmed(db, new Date("2026-10-10T09:00:00Z"));
  assert.equal(row("waiting@example.com"), undefined);
  assert.ok(row("joined@example.com"));
});

test("only its own POSTs are answered", async () => {
  const { newsletter } = setUp();
  assert.equal(await answer(new Request("https://orbtorrent.com/subscribe"), newsletter), null);
  assert.equal(await answer(new Request("https://orbtorrent.com/subscribe/confirm?token=x"), newsletter), null);
  assert.equal(await answer(new Request("https://orbtorrent.com/download", { method: "POST" }), newsletter), null);
});

test("addresses", () => {
  assert.equal(normalise(" Name.Surname+news@Mail.Example.co.uk "), "name.surname+news@mail.example.co.uk");
  assert.equal(normalise("someone@xn--bcher-kva.example"), "someone@xn--bcher-kva.example");
  for (const wrong of ["", "someone", "someone@", "@example.com", "some one@example.com", "someone@example", "a@b@example.com", "someone@-example.com", `${"a".repeat(65)}@example.com`]) {
    assert.equal(normalise(wrong), null, wrong);
  }
});
