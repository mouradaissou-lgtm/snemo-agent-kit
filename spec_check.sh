#!/usr/bin/env bash
# spec_check.sh — the functional-spec test: verifies AGENT_SPEC.md is coherent.
#
# Checks (all deterministic, POSIX-bash + python3 only, no deps):
#   1. every group header has a declared count "(N)" and the actual ### entries match it;
#   2. every entry id is unique and matches ^[A-I]([0-9]+)([a-z]?)$ ;
#   3. every entry has at least a "Purpose:" line (the base contract — a function with no
#      stated purpose is not specified);
#   4. FULL entries carry the four-field contract (Purpose/Mechanism/I/O/Composes) promised by
#      the spec header; gate-inventory entries (the C-group) may be terse "Purpose:" one-liners —
#      these are reported as "terse" (info), not failures;
#   5. referenced gate files (backticks `foo.sh` / `foo.py` within C-group) exist in the
#      instance-template's 06_gates set OR GBC's canonical 06_gates (so a spec entry never names a
#      gate that isn't shipped);
#   6. no un-substituted {{placeholders}} in the spec.
#
# Usage:
#   bash spec_check.sh [--root <generator-dir>] [--json]
# Exit 0 = coherent, 1 = at least one FAIL.
#
# The spec is the SOURCE OF TRUTH for what an instance is. This test is the guard that the spec
# text stays coherent as it grows; make_instance.sh / test_instance.sh / core_check.sh consume the
# same ids, so a spec that fails here would silently desync the namespace.

set -u
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SPEC="$DIR/AGENT_SPEC.md"
JSON=0
ROOT="$DIR"
while [ $# -gt 0 ]; do
  case "$1" in
    --json) JSON=1; shift ;;
    --root) ROOT="$2"; shift 2 ;;
    *) shift ;;
  esac
done
[ -f "$SPEC" ] || { echo "FAIL: spec not found: $SPEC"; exit 1; }

# Canonical trees to resolve referenced files against: template tree + generator + full GBC.
TEMPLATE_GATES="$ROOT/instance-template/06_gates"
GBC_TREE="/Users/mouradaissou/GBC/Snemo Agent"

out="$(python3 - "$SPEC" "$TEMPLATE_GATES" "$GBC_TREE" "$ROOT" <<'PY'
import re, sys, os
spec, tg, gbc, root = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
txt = open(spec, encoding='utf8').read()
lines = txt.splitlines()

fails = []; warns = []; infos = []

# ---- 1 & 2: group declared counts, entry ids, uniqueness --------------------
group_re = re.compile(r'^## ([A-I])\. .*?\((\d+)\)\s*$')
entry_re = re.compile(r'^### ([A-I])(\d+)([a-z]?)')
groups = {}
order = []
cur = None
for ln in lines:
    gm = group_re.match(ln)
    if gm:
        cur = gm.group(1)
        order.append(cur)
        groups[cur] = {'declared': int(gm.group(2)), 'entries': []}
    em = entry_re.match(ln)
    if em and cur:
        g = em.group(1)
        num = em.group(2)
        tail = em.group(3)
        eid = f"{g}{num}{tail}"
        if g != cur:
            fails.append(f"group drift: entry {eid} appears under group {cur} but id says {g}")
        groups[cur]['entries'].append(eid)

# uniqueness
seen = {}
for e in order:
    for eid in groups[e]['entries']:
        seen.setdefault(eid, 0)
        seen[eid] += 1
for eid, c in seen.items():
    if c > 1:
        fails.append(f"duplicate entry id: {eid} (x{c})")

# declared vs actual
for g in order:
    d = groups[g]['declared']; a = len(groups[g]['entries'])
    if d != a:
        fails.append(f"group {g}: header says ({d}) but has {a} entries")

# ---- 3 & 4: per-entry field contract ----------------------------------------
# Rebuild entry blocks.
blocks = []
cur_g = None; cur_e = None; body = []
for ln in lines:
    gm = group_re.match(ln)
    if gm:
        cur_g = gm.group(1); continue
    em = entry_re.match(ln)
    if em:
        if cur_e is not None:
            blocks.append((cur_e, body))
        cur_e = f"{em.group(1)}{em.group(2)}{em.group(3)}"
        body = []
        continue
    if cur_e is not None:
        body.append(ln)
if cur_e is not None:
    blocks.append((cur_e, body))

FIELD = ['Purpose', 'Mechanism', 'I/O', 'Composes']
for eid, body in blocks:
    b = '\n'.join(body)
    purpose = re.search(r'^- \*\*Purpose:\*\*', b, re.M)
    if not purpose:
        fails.append(f"{eid}: missing **Purpose:** (a function with no stated purpose is not specified)")
        continue
    fields = [f for f in FIELD if re.search(r'^- \*\*' + re.escape(f) + r':\*\*', b, re.M)]
    if len(fields) == 4:
        continue
    # gate-inventory group C may be terse; any other incomplete full entry is a warn.
    if eid.startswith('C'):
        infos.append(f"{eid}: terse (Purpose only or '+{len(fields)}' field) — gate-inventory ok")
    else:
        warns.append(f"{eid}: full contract expected ({', '.join(FIELD)}) but has ({', '.join(fields)})")

# ---- 5: referenced files exist somewhere shipped (template tree or generator) ------
# A referenced `foo.sh`/`foo.py` may be a gate, a tool, or a machinery script; resolve it against
# the template tree + the generator dir + GBC canonical, not just 06_gates.
import glob
def walk(base):
    for dirpath, _dirs, files in os.walk(base):
        for f in files:
            yield os.path.join(dirpath, f)
ship = set()
for base in (f"{root}/instance-template", root, tg, gbc):
    if os.path.isdir(base):
        for p in walk(base):
            ship.add(os.path.basename(p))
def exists(fn):
    return fn in ship or os.path.exists(fn)
gate_ref_re = re.compile(r'`([A-Za-z0-9_.\-]+\.(?:sh|py))`')
refs = set()
for eid, body in blocks:
    for m in gate_ref_re.finditer('\n'.join(body)):
        refs.add(m.group(1))
for fn in sorted(refs):
    if not exists(fn):
        fails.append(f"spec references a file not found in template/generator/GBC: `{fn}`")

# ---- 6: placeholders ---------------------------------------------------------
ph = re.findall(r'\{\{[^}]+\}\}', txt)
if ph:
    fails.append(f"un-substituted placeholders in spec: {sorted(set(ph))}")

# ---- emit --------------------------------------------------------------------
print("SPEC: %d entries, %d groups" % (len(seen), len(order)))
for i in infos: print("info " + i)
for w in warns: print("WARN " + w)
for f in fails: print("FAIL " + f)
print("RESULT: %d FAIL, %d WARN" % (len(fails), len(warns)))
sys.exit(1 if fails else 0)
PY
)"
rc=$?
echo "$out"
if [ "$JSON" = 1 ]; then
  f=$(echo "$out" | grep -c '^FAIL'); w=$(echo "$out" | grep -c '^WARN'); p=$(echo "$out" | grep -c '^PASS')
  printf '{"fails":%d,"warns":%d,"healthy":%s}\n' "$f" "$w" "$([ "$rc" -eq 0 ] && echo true || echo false)"
fi
exit "$rc"
