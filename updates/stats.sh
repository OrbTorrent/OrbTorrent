#!/usr/bin/env bash
#
# How many Macs checked for updates each day, by version: each copy of
# OrbTorrent checks about once a day, so a day's checks are roughly the Macs
# using it that day.
#
# Usage: updates/stats.sh [days]   (the last 14 by default)

set -euo pipefail
DAYS="${1:-14}"
[[ "$DAYS" =~ ^[0-9]+$ ]] || { echo "usage: stats.sh [days]" >&2; exit 64; }
cd "$(dirname "$0")"

npx --no-install cf analytics_engine sql query --body "
  SELECT toDate(timestamp) AS day, blob2 AS version, blob3 AS build, SUM(_sample_interval) AS checks
  FROM orbtorrent_update_checks
  WHERE index1 = 'appcast.xml' AND blob1 = 'OrbTorrent' AND timestamp > NOW() - INTERVAL '$DAYS' DAY
  GROUP BY day, version, build
  ORDER BY day DESC, checks DESC
  FORMAT JSON" |
python3 -c '
import json, sys
rows = json.load(sys.stdin)["data"]
if not rows:
    sys.exit("No update checks yet.")
days = {}
for row in rows:
    days.setdefault(row["day"], []).append(row)
print("%-12s%6s  %s" % ("Day", "Macs", "Versions"))
for day, versions in days.items():
    total = sum(int(r["checks"]) for r in versions)
    detail = ", ".join("%s (%s): %s" % (r["version"], r["build"], r["checks"]) for r in versions)
    print("%-12s%6d  %s" % (day, total, detail))
'
