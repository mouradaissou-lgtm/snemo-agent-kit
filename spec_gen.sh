#!/usr/bin/env bash
# spec_gen.sh — generate + update the functional-spec artifacts for the agent instance system.
#
# The canonical spec is AGENT_SPEC.md (source of truth for "what an instance is"). This tool does
# three things:
#   generate  --emit <json>   parse the spec into a machine-readable index (groups + entries + fields).
#   drift     --drift         report entries that don't meet the 4-field contract (Purpose/Mechanism/I-O/
#                             Composes) promised by the spec header — i.e. WHAT needs updating.
#   sync      --sync          inject a "spec contract" presence check into the template's core_check.sh
#                             and the generator's test_instance.sh, so a generated instance is tested
#                             against the spec's structure (uniqueness + group-count + purpose-present).
#
# Usage:
#   bash spec_gen.sh generate --emit spec_index.json
#   bash spec_gen.sh drift                       # exit 0 if no full-contract entry lacks a field
#   bash spec_gen.sh sync                        # rewrites template checks to include the spec contract
#   bash spec_gen.sh --help
#
# POSIX-bash + python3 only, deterministic, no deps. The JSON index is the machine contract that
# make_instance.sh / test_instance.sh / core_check.sh can consume to stay in lockstep with the spec.

set -u
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SPEC="$DIR/AGENT_SPEC.md"
TEMPLATE_CORE="$DIR/instance-template/core_check.sh"
TEST_INSTANCE="$DIR/test_instance.sh"
JSON_OUT=""

python() { python3 "$@"; }

emit() {
  # emit <path>  — build the machine index by mirroring the spec's structure.
  python - "$SPEC" "$1" <<'PY'
import re, sys, json
spec, out = sys.argv[1], sys.argv[2]
txt = open(spec, encoding='utf8').read()
lines = txt.splitlines()
FIELD = ['Purpose', 'Mechanism', 'I/O', 'Composes']
node = {"groups": [], "entries": {}}
curg = None
group_re = re.compile(r'^## ([A-I])\. (.*?) \((\d+)\)\s*$')
entry_re = re.compile(r'^### ([A-I])(\d+)([a-z]?)\s*—?\s*(.*)$')
blocks = []
ceid = None; body = []
for ln in lines:
    gm = group_re.match(ln)
    if gm:
        curg = {"id": gm.group(1), "title": gm.group(2), "declared": int(gm.group(3)), "entries": []}
        node["groups"].append(curg)
        continue
    em = entry_re.match(ln)
    if em and curg is not None:
        if ceid is not None:
            blocks.append((ceid, body))
        eid = "%s%s%s" % (em.group(1), em.group(2), em.group(3))
        title = em.group(4).strip()
        ceid = eid; body = []
        node["entries"][eid] = {"id": eid, "group": curg["id"], "title": title, "fields": {}}
        curg["entries"].append(eid)
        continue
    if ceid is not None:
        body.append(ln)
if ceid is not None:
    blocks.append((ceid, body))

for eid, body in blocks:
    b = '\n'.join(body)
    for f in FIELD:
        m = re.search(r'^- \*\*' + re.escape(f) + r':\*\* ?(.*)$', b, re.M)
        if m:
            node["entries"][eid]["fields"][f] = m.group(1).strip()
json.dump(node, open(out, 'w', encoding='utf8'), ensure_ascii=False, indent=2)
print("index written:", out, "|", len(node["entries"]), "entries,", len(node["groups"]), "groups")
PY
}

drift() {
  # Report entries missing the full 4-field contract. exit 0 = none, 1 = drift present.
  python - "$SPEC" <<'PY'
import re, sys
spec = sys.argv[1]
txt = open(spec, encoding='utf8').read()
lines = txt.splitlines()
FIELD = ['Purpose', 'Mechanism', 'I/O', 'Composes']
entry_re = re.compile(r'^### ([A-I]\d+[a-z]?)\s*—?\s*(.*)$')
eid = None; body = []; blocks = []
for ln in lines:
    em = entry_re.match(ln)
    if em:
        if eid is not None: blocks.append((eid, body))
        eid = em.group(1); body = []
        continue
    if eid is not None: body.append(ln)
if eid is not None: blocks.append((eid, body))
bad = []
for eid, body in blocks:
    b = '\n'.join(body)
    if not re.search(r'^- \*\*Purpose:\*\*', b, re.M):
        bad.append((eid, 'no Purpose'))
        continue
    # C-group is a documented terse gate-inventory; non-C entries should be full.
    if eid.startswith('C'):
        continue
    have = [f for f in FIELD if re.search(r'^- \*\*' + re.escape(f) + r':\*\*', b, re.M)]
    if have != FIELD:
        bad.append((eid, 'missing: ' + ', '.join(x for x in FIELD if x not in have)))
for eid, why in bad:
    print("DRIFT %s — %s" % (eid, why))
print("RESULT: %d entry(ies) below the full contract" % len(bad))
sys.exit(1 if bad else 0)
PY
}

sync() {
  # Make the spec part of the generation/test chain. The spec is a GENERATOR-level artifact
  # (it defines what an instance is), so the spec-contract checks belong in the generator's own
  # test (test_instance.sh) — NOT in each instance's core_check.sh (instances don't ship the spec).
  # This is idempotent: a marker makes re-running a no-op.
  marker="spec_check.sh"

  if grep -q "$marker" "$TEST_INSTANCE" 2>/dev/null; then
    echo "test_instance.sh already runs the spec contract (no-op)"
  else
    GEN="$DIR" python3 - "$TEST_INSTANCE" <<'PY'
import sys, os
p = sys.argv[1]
gen = os.environ.get('GEN')
t = open(p, encoding='utf8').read()
block = (
    '\n'
    '# --- 9. spec contract: the functional spec must be coherent (generate + test the spec) --------\n'
    f'  bash "{gen}/spec_check.sh" >/dev/null 2>&1; ck "spec_check.sh coherent" "0" "$?"\n'
    f'  if bash "{gen}/spec_gen.sh" generate /tmp/spec_index_check.json >/dev/null 2>&1 '
    '&& [ -s /tmp/spec_index_check.json ]; then rm -f /tmp/spec_index_check.json; '
    'ck "spec_gen generates index" "0" "0"; else ck "spec_gen generates index" "0" "1"; fi\n'
)
marker = 'rm -rf "$TMP"'
if marker in t:
    t = t.replace(marker, block + marker, 1)
    open(p, 'w', encoding='utf8').write(t)
    print("test_instance.sh: added spec-contract checks (spec_check + spec_gen)")
else:
    print("test_instance.sh: marker not found — left unchanged")
PY
  fi
}

catalog() {
  # catalog --emit <tests/spec_catalog.json> — build the spec-conformance SKELETON from the spec.
  # One row per spec entry: id/group/name/nature/status/proof. Every entry starts "todo" with an
  # empty proof: the instance's own tests promote rows to "covered" (with proof) via
  # 06_gates/update_spec_tracker.sh. Derived from the spec, so the skeleton can never drift from it.
  local out="$DIR/spec_catalog.json"
  while [ $# -gt 0 ]; do
    case "$1" in
      --emit) out="$2"; shift 2 ;;
      *) shift ;;
    esac
  done
  python - "$SPEC" "$out" <<'PY'
import re, sys, json
spec, out = sys.argv[1], sys.argv[2]
txt = open(spec, encoding='utf8').read()
group_re = re.compile(r'^## ([A-I])\. (.*?) \((\d+)\)\s*$')
entry_re = re.compile(r'^### ([A-I])(\d+)([a-z]?)\s*—?\s*(.*)$')
groups, funcs = {}, []
curg = None; cur = None
for ln in txt.splitlines():
    gm = group_re.match(ln)
    if gm:
        curg = gm.group(1)
        groups[curg] = {"title": gm.group(2), "n": int(gm.group(3))}
        continue
    em = entry_re.match(ln)
    if em and curg:
        eid = "%s%s%s" % (em.group(1), em.group(2), em.group(3))
        cur = {"id": eid, "group": curg, "name": em.group(4).strip(),
               "nature": "comportement", "status": "todo", "proof": ""}
        funcs.append(cur)
# nature: gates/discipline entries (C-group) and infra (G-group) are "mécanique"; the rest "comportement".
for f in funcs:
    if f["group"] in ("C", "G"):
        f["nature"] = "mécanique"
def sortkey(f):
    m = re.match(r'^([A-I])(\d+)([a-z]?)$', f["id"])
    return (m.group(1), int(m.group(2)), m.group(3) or "")
funcs.sort(key=sortkey)
doc = {"meta": {"title": "Suivi du test de l'agent (spec AGENT_SPEC.md)",
                "spec": "AGENT_SPEC.md", "total": len(funcs),
                "vocabulary": ["todo", "covered", "partial", "absent", "na"]},
       "groups": groups, "functions": funcs}
json.dump(doc, open(out, 'w', encoding='utf8'), ensure_ascii=False, indent=2)
print("catalog written:", out, "|", len(funcs), "functions,", len(groups), "groups")
PY
}

coverage() {
  # coverage --catalog <spec_catalog.json> --emit <spec_coverage.json>
  # DERIVE the coverage counters from the catalog (single source of truth => always reconciles).
  # Vocabulary mapping: covered->conform, partial->partiel, todo->todo (present but NOT yet proven —
  # kept distinct so a fresh, unaudited instance never reports conformance), absent/manquant->absent, na->na.
  python3 - "$@" <<'PY'
import sys, json, os
a = sys.argv[1:]
cat = em = None
i = 0
while i < len(a):
    if a[i] == '--catalog': cat = a[i+1]; i += 2
    elif a[i] == '--emit':  em  = a[i+1]; i += 2
    else: i += 1
if not cat or not em:
    print("usage: spec_gen.sh coverage --catalog <catalog.json> --emit <coverage.json>", file=sys.stderr)
    sys.exit(2)
d = json.load(open(cat, encoding='utf8'))
funcs = d.get('functions', [])
MAP = {'covered': 'conform', 'partial': 'partiel', 'todo': 'todo',
       'absent': 'absent', 'manquant': 'absent', 'na': 'na'}
counts = {'conform': 0, 'partiel': 0, 'todo': 0, 'absent': 0, 'na': 0}
unknown = []
for f in funcs:
    st = str(f.get('status', 'todo')).strip().lower()
    if st not in MAP:
        unknown.append(st); continue
    counts[MAP[st]] += 1
if unknown:
    print("FAIL: unknown status vocabulary:", sorted(set(unknown)), file=sys.stderr); sys.exit(1)
tot = sum(counts.values())
if tot != len(funcs):
    print(f"FAIL: categorized {tot} != {len(funcs)} functions", file=sys.stderr); sys.exit(1)
out = {"conform": counts['conform'], "total": tot,
       "partiel": counts['partiel'], "todo": counts['todo'],
       "absent": counts['absent'], "na": counts['na']}
json.dump(out, open(em, 'w', encoding='utf8'), ensure_ascii=False, indent=2)
print(f"coverage written: {em} | {out}")
PY
}

case "${1:-}" in
  generate) emit "${2:-$DIR/spec_index.json}" ;;
  catalog)  catalog "${@:2}" ;;
  coverage) coverage "${@:2}" ;;
  drift)    drift ;;
  sync)     sync ;;
  --help|-h) sed -n '1,40p' "$0" ;;
  *) echo "usage: spec_gen.sh generate|catalog|coverage|drift|sync"; exit 1 ;;
esac
