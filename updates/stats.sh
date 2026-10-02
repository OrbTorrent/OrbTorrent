#!/usr/bin/env bash
#
# What OrbTorrent's update checks say: how many Macs use it each day, week
# and month, new installs, versions, unexpected quits by version, how many
# keep using it, and macOS and chip. Each copy checks about once a day, so a
# day's checks are roughly the Macs using it that day. The counts are
# described in AnonymousCounts.swift.
#
# Usage: updates/stats.sh [days]   (the last 14 by default; Cloudflare keeps 90)

set -euo pipefail
DAYS="${1:-14}"
[[ "$DAYS" =~ ^[0-9]+$ ]] || { echo "usage: stats.sh [days]" >&2; exit 64; }
cd "$(dirname "$0")"

DAYS="$DAYS" python3 - <<'PY'
import json, os, subprocess
from concurrent.futures import ThreadPoolExecutor

DAYS = int(os.environ["DAYS"])
# Where each count is stored: see src/counts.ts.
CHECK, MACOS, CHIP, INSTALLED, NEW, WEEK, MONTH = (f"blob{n}" for n in range(4, 11))
# A Mac on a day: every check but the ones asked for, which come on top.
DAILY = f"if({CHECK} = 'manual', 0, _sample_interval)"

def where(days):
    return f"FROM orbtorrent_update_checks WHERE index1 = 'appcast.xml' AND blob1 = 'OrbTorrent' AND timestamp > NOW() - INTERVAL '{days}' DAY"

def query(sql):
    out = subprocess.run(["npx", "--no-install", "cf", "analytics_engine", "sql", "query", "--body", sql + " FORMAT JSON"],
                         check=True, capture_output=True, text=True).stdout
    return json.loads(out)["data"]

def share(sql_value, extra=""):
    return f"SELECT {sql_value} AS value, SUM({DAILY}) AS n {where(DAYS)} {extra} GROUP BY value ORDER BY n DESC"

queries = {
    "days": f"""SELECT toDate(timestamp) AS day, blob2 AS version, blob3 AS build, SUM({DAILY}) AS macs,
        sumIf(_sample_interval, {NEW} = '1') AS new, SUM(_sample_interval * double2) AS quits,
        SUM(_sample_interval * double3) AS stops {where(DAYS)} GROUP BY day, version, build ORDER BY day DESC""",
    "weeks": f"""SELECT formatDateTime(timestamp, '%G-W%V') AS week, sumIf(_sample_interval, {WEEK} = '1') AS macs,
        sumIf(_sample_interval, {NEW} = '1') AS new {where(90)} GROUP BY week ORDER BY week DESC""",
    "months": f"""SELECT formatDateTime(timestamp, '%Y-%m') AS month, sumIf(_sample_interval, {MONTH} = '1') AS macs
        {where(90)} GROUP BY month ORDER BY month DESC""",
    "cohorts": f"""SELECT {INSTALLED} AS installed, formatDateTime(timestamp, '%G-W%V') AS week,
        sumIf(_sample_interval, {NEW} = '1') AS new, sumIf(_sample_interval, {WEEK} = '1') AS active
        {where(90)} AND {INSTALLED} != '' GROUP BY installed, week""",
    "macos": share(MACOS, f"AND {MACOS} != ''"),
    "chip": share(CHIP, f"AND {CHIP} != ''"),
}

with ThreadPoolExecutor(8) as pool:
    results = dict(zip(queries, pool.map(query, queries.values())))

if not results["days"]:
    raise SystemExit("No update checks yet.")

def n(row, key="n"):
    return int(float(row[key]))

def percentages(rows, limit=8):
    total = sum(n(r) for r in rows) or 1
    return ", ".join(f"{r['value']} {round(100 * n(r) / total)}%" for r in rows[:limit])

print(f"OrbTorrent's update checks, the last {DAYS} days. A Mac checks about once a day.\n")

days = {}
for row in results["days"]:
    days.setdefault(row["day"], []).append(row)
print("%-12s%6s%6s  %s" % ("Day", "Macs", "New", "Versions"))
for day, versions in days.items():
    versions.sort(key=lambda r: -n(r, "macs"))
    detail = ", ".join(f"{r['version']} ({r['build']}): {n(r, 'macs')}" for r in versions if n(r, "macs"))
    print("%-12s%6d%6d  %s" % (day, sum(n(r, "macs") for r in versions), sum(n(r, "new") for r in versions), detail))

weeks, months = results["weeks"][:6], results["months"][:3]
print("\n%-12s%6s%10s      %-10s%6s" % ("Week", "Macs", "Installs", "Month", "Macs"))
for i in range(max(len(weeks), len(months))):
    week = "%-12s%6d%10d" % (weeks[i]["week"], n(weeks[i], "macs"), n(weeks[i], "new")) if i < len(weeks) else " " * 28
    month = "      %-10s%6d" % (months[i]["month"], n(months[i], "macs")) if i < len(months) else ""
    print(week + month)

by_version = {}
for row in results["days"]:
    name = f"{row['version']} ({row['build']})"
    totals = by_version.setdefault(name, [0, 0, 0])
    totals[0] += n(row, "macs"); totals[1] += n(row, "quits"); totals[2] += n(row, "stops")
print("\nUnexpected quits, per 100 Macs a day")
print("%-18s%10s%12s%9s" % ("Version", "Mac-days", "OrbTorrent", "Engine"))
for name, (macs, quits, stops) in sorted(by_version.items(), key=lambda item: -item[1][0]):
    if macs:
        print("%-18s%10d%12.1f%9.1f" % (name, macs, 100 * quits / macs, 100 * stops / macs))

cohorts = {}
for row in results["cohorts"]:
    cohort = cohorts.setdefault(row["installed"], {"new": 0, "weeks": {}})
    cohort["new"] += n(row, "new")
    cohort["weeks"][row["week"]] = n(row, "active")
if cohorts and weeks:
    this_week = weeks[0]["week"]
    last_week = weeks[1]["week"] if len(weeks) > 1 else None
    print("\nStill using it, by the week installed")
    print("%-12s%10s%14s%14s" % ("Installed", "Installs", "Last week", "This week"))
    def active(cohort, week):
        count = cohort["weeks"].get(week, 0) if week else 0
        return f"{count} ({round(100 * count / cohort['new'])}%)" if cohort["new"] else str(count)
    for installed in sorted(cohorts, reverse=True)[:12]:
        cohort = cohorts[installed]
        print("%-12s%10d%14s%14s" % (installed, cohort["new"], active(cohort, last_week), active(cohort, this_week)))

print()
if results["macos"]:
    print("macOS: " + percentages(results["macos"]))
if results["chip"]:
    print("Chip: " + percentages(results["chip"]))

PY
