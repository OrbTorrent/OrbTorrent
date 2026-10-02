-- The people who asked to hear about OrbTorrent's big releases, from the
-- sign-up in the site's footer (src/lib/newsletter.ts). An address joins the
-- list once its owner confirms it from the email sent to it; until then it's
-- deleted after 7 days. Nothing else about anyone is kept.
CREATE TABLE subscribers (
  -- In lower case.
  email TEXT PRIMARY KEY,
  -- In the links to confirm and to unsubscribe. A new one with each
  -- confirmation email, so only the latest link works.
  token TEXT NOT NULL UNIQUE,
  -- When they first asked, when the latest confirmation email went, and when
  -- they confirmed: ISO 8601, in UTC.
  signed_up_at TEXT NOT NULL,
  sent_at TEXT,
  confirmed_at TEXT
);
