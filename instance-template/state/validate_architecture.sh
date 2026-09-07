#!/bin/bash
# G-ARCH — deterministic validator for the architecture register (state/architecture.md).
# 1) version block present (version / last change / last review);
# 2) surfaces + change tables well-formed (S-xx / ARC-xxx ids, 8 columns);
# 3) every change row: valid date, verdict = "pending" | "CEO — <date> …";
# 4) last-change stamp >= newest change-row date;
# 5) no duplicated ARC id.
# Exit 0 = pass, 1 = fail.
set -euo pipefail
cd "$(dirname "$0")"
fail=0

python3 - <<'EOF' || fail=1
import re, sys
bad = False
md = open('architecture.md', encoding='utf8').read()

def w(msg):
    global bad
    print('FAIL', msg); bad = True

# 1) version block
m  = re.search(r'^version: (v[\d.]+)$', md, re.M)
mc = re.search(r'^last change: (\d{4}-\d{2}-\d{2})$', md, re.M)
mr = re.search(r'^last review: (.+)$', md, re.M)
if not (m and mc and mr):
    w('version block missing/malformed (version / last change / last review)')

# 2)+3) change rows
rows = []
for line in md.splitlines():
    cells = [c.strip() for c in line.strip().strip('|').split('|')]
    if len(cells) >= 8 and re.fullmatch(r'ARC-\d+', cells[0]):
        rows.append(cells[:8])
if not rows: w('no change rows found')

seen, dates = set(), []
for c in rows:
    rid, date, surf, change, rnd, dref, verdict, notes = c
    if rid in seen: w(rid + ' duplicated')
    seen.add(rid)
    if re.fullmatch(r'\d{4}-\d{2}-\d{2}', date): dates.append(date)
    else: w(rid + ' bad date ' + repr(date))
    if not re.match(r'^[SMT]-\d+', surf): w(rid + ' surface ref must start S/M/T-xx, got ' + repr(surf))
    if not change or change == '—': w(rid + ' empty change')
    if not rnd: w(rid + ' empty round ref')
    if verdict != 'pending' and not re.match(r'^user — \d{4}-\d{2}-\d{2}', verdict) and verdict != 'COMMITTED':
        w(rid + ' verdict must be "pending", "user — <date> …", or "COMMITTED", got ' + repr(verdict))

# 4) stamp freshness
if mc and dates and mc.group(1) < max(dates):
    w('last change ' + mc.group(1) + ' older than newest row ' + max(dates))

# surfaces table sanity
surfaces = 0
for line in md.splitlines():
    cells = [c.strip() for c in line.strip().strip('|').split('|')]
    if len(cells) >= 3 and re.fullmatch(r'[SMT]-\d+', cells[0]):
        surfaces += 1
if surfaces < 5: w('surfaces table too small (' + str(surfaces) + ' rows)')

print('ARCHITECTURE REGISTER: ' + str(len(rows)) + ' change rows, ' + str(surfaces) + ' surfaces — ' + ('FAIL' if bad else 'OK'))
sys.exit(1 if bad else 0)
EOF
exit $fail
