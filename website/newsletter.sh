#!/usr/bin/env bash
#
# The email sign-up's list, "Hear about big releases" (src/lib/newsletter.ts),
# from the D1 database orbtorrent-newsletter, kept in the EU.
#
# Usage:
#   website/newsletter.sh           How many have confirmed, and how many are
#                                   waiting to (deleted after 7 days)
#   website/newsletter.sh export    The confirmed addresses as CSV, with when
#                                   each signed up and confirmed, for the
#                                   service that sends the 1.0 email. It's
#                                   their proof of consent. Keep the file
#                                   private, and delete it once it's imported.

set -euo pipefail
DATABASE=54d91a81-0c6c-482d-963c-038bd96d6e42
cd "$(dirname "$0")"

query() {
  npx --no-install cf d1 query "$DATABASE" --sql "$1" | python3 -c 'import json, sys; print(json.dumps(json.load(sys.stdin)[0]["results"]))'
}

case "${1:-}" in
  "")
    query "SELECT COUNT(confirmed_at) AS confirmed, COUNT(*) - COUNT(confirmed_at) AS waiting,
      SUM(confirmed_at > strftime('%Y-%m-%dT%H:%M:%fZ', 'now', '-7 days')) AS this_week FROM subscribers" | python3 -c '
import json, sys
row = json.load(sys.stdin)[0]
print("%s on the list (%s this week), %s waiting to confirm." % (row["confirmed"], row["this_week"] or 0, row["waiting"]))'
    ;;
  export)
    query "SELECT email, signed_up_at, confirmed_at FROM subscribers WHERE confirmed_at IS NOT NULL ORDER BY confirmed_at" | python3 -c '
import csv, json, sys
writer = csv.writer(sys.stdout)
writer.writerow(["email", "signed_up_at", "confirmed_at"])
for row in json.load(sys.stdin):
    writer.writerow([row["email"], row["signed_up_at"], row["confirmed_at"]])'
    ;;
  *)
    sed -n '3,13p' "$0" | sed 's/^# \{0,1\}//' >&2
    exit 64
    ;;
esac
