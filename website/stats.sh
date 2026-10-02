#!/usr/bin/env bash
#
# How many times OrbTorrent was downloaded from orbtorrent.com each day, where
# Download was clicked (a page of the site, or the site that linked to it), and
# from which countries. The Worker, src/worker.ts, counts each one.
#
# GitHub counts every download of the disk image too, including the ones
# OrbTorrent makes to update itself: gh release view --json assets.
#
# Usage: website/stats.sh [days]   (the last 14 by default)

set -euo pipefail
DAYS="${1:-14}"
[[ "$DAYS" =~ ^[0-9]+$ ]] || { echo "usage: stats.sh [days]" >&2; exit 64; }
cd "$(dirname "$0")"

query() {
  npx --no-install cf analytics_engine sql query --body "$1 FORMAT JSON"
}

DAILY="$(query "
  SELECT toDate(timestamp) AS day, blob1 AS source, SUM(_sample_interval) AS downloads
  FROM orbtorrent_downloads
  WHERE index1 = 'mac' AND timestamp > NOW() - INTERVAL '$DAYS' DAY
  GROUP BY day, source
  ORDER BY day DESC, downloads DESC")"
COUNTRIES="$(query "
  SELECT blob3 AS country, SUM(_sample_interval) AS downloads
  FROM orbtorrent_downloads
  WHERE index1 = 'mac' AND timestamp > NOW() - INTERVAL '$DAYS' DAY
  GROUP BY country
  ORDER BY downloads DESC
  LIMIT 15")"

python3 - "$DAILY" "$COUNTRIES" <<'EOF'
import json, sys
daily = json.loads(sys.argv[1])["data"]
countries = json.loads(sys.argv[2])["data"]
if not daily:
    sys.exit("No downloads yet.")
days = {}
for row in daily:
    days.setdefault(row["day"], []).append(row)
print("%-12s%10s  %s" % ("Day", "Downloads", "From"))
for day, sources in days.items():
    total = sum(int(r["downloads"]) for r in sources)
    detail = ", ".join("%s: %s" % (r["source"] or "direct", r["downloads"]) for r in sources)
    print("%-12s%10d  %s" % (day, total, detail))
print()
print("Countries: " + ", ".join("%s %s" % (r["country"] or "unknown", r["downloads"]) for r in countries))
EOF
