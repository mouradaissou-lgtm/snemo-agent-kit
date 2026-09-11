#!/usr/bin/env bash
# test_instance.sh — automated regression test for make_instance.sh.
# Runs the generator on a temp target and asserts the produced instance is complete
# and clean: all groups present, gates resolve, digest generated, boot stamp OK,
# zero business strings, no un-substituted placeholders.
# Usage: test_instance.sh   ; exit 0 = all pass, 1 = any fail.
set -u

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GEN="$DIR/make_instance.sh"
TMP="$(mktemp -d /tmp/inst_test.XXXXXX)"
TARGET="$TMP/TestAgent"
NAME="Acme Advisory"
PRESET_DIR="$(printf '%s' "$NAME" | tr '[:upper:] ' '[:lower:]-')"
PASS=0; FAIL=0
ck(){ if [ "$2" = "$3" ]; then echo "  OK $1"; PASS=$((PASS+1)); else echo "  XX $1 : attendu=$2 obtenu=$3"; FAIL=$((FAIL+1)); fi; }

[ -f "$GEN" ] || { echo "FAIL: generator not found: $GEN"; exit 1; }
[ -d "$DIR/instance-template" ] || { echo "FAIL: instance-template not found"; exit 1; }

# --- 0. refuse non-empty target ----------------------------------------------
mkdir -p "$TMP/occupied"; echo x > "$TMP/occupied/f.txt"
out="$(bash "$GEN" "$TMP/occupied" "X" 2>&1 || true)"
echo "$out" | grep -q "refusing\|not empty" && ck "refuse non-empty target" "0" "0" || ck "refuse non-empty target" "refuse" "no-refuse"

# --- 1. scaffold -------------------------------------------------------------
bash "$GEN" "$TARGET" "$NAME" >/dev/null 2>&1 || { echo "FAIL: generator exited non-zero"; exit 1; }

# --- 2. groups present (GBC-parity) ------------------------------------------
for f in AGENT_CORE.md AGENTS.md READ_FIRST.md state/memory/MODE state/memory/beliefs.md \
         state/memory/facts.md state/memory/make_brief.sh state/gates/brains.sh \
         state/agenda.md state/projects.md state/architecture.md \
         state/resolve_machinery.sh state/validate_architecture.sh \
         SPEC/01_IDENTITY_PURPOSE.md SPEC/03_BEHAVIOR_RULES.md \
         09_task_goals/SCHEMA.md 09_task_goals/TASK_GOALS.md 09_task_goals/TODO.md \
         Machinery/00_purpose/PURPOSE.md Machinery/02_framework/PERSONA.md \
         Machinery/02_framework/FRAMEWORK.md Machinery/02_framework/BRIEF_TEMPLATE.md \
         Machinery/03_logs/DECISION_LOG.md Machinery/03_logs/DECISION_QUEUE.md Machinery/03_logs/ROUND_LOG.md \
         Machinery/08_rh/README.md preset/$PRESET_DIR/preset.yml preset/$PRESET_DIR/src/behavior.ts \
         06_gates/verify_ledger.sh 06_gates/production_gate.py tests/test_gate.sh tests/make_fixture.py DOCTRINE.md AGENT_SPEC.md \
         Machinery/cockpit/dashboard_server.js Machinery/cockpit/dashboard.html Machinery/cockpit/monitor.py \
         Machinery/07_reports/serve_deliverables.py Machinery/07_reports/update_deliverables_index.py \
         Machinery/02_framework/AGENT_CORE_machinery_contract.md; do
  [ -e "$TARGET/$f" ] && ck "present: $f" "0" "0" || ck "present: $f" "present" "MISSING"
done
# 2b1. Functional spec wired into ORIENT (lean §0): present + agent_core + behavior point to it
[ -s "$TARGET/AGENT_SPEC.md" ] && ck "AGENT_SPEC.md non-empty" "0" "0" || ck "AGENT_SPEC.md non-empty" "non-empty" "EMPTY"
grep -q "AGENT_SPEC.md" "$TARGET/AGENT_CORE.md" && ck "AGENT_CORE ORIENT references AGENT_SPEC.md" "0" "0" || ck "AGENT_CORE ORIENT ref AGENT_SPEC" "present" "MISSING"
grep -qi "AGENT_SPEC.md" "$TARGET/preset/$PRESET_DIR/src/behavior.ts" && ck "behavior.ts points at AGENT_SPEC.md" "0" "0" || ck "behavior.ts AGENT_SPEC pointer" "present" "MISSING"
# 2b. DOCTRINE independence: aggregation rule present; behavior.ts generic (no instance-specific sentence)
grep -qi "never" "$TARGET/DOCTRINE.md" && grep -qiE "aggregate|agrég|engine|moteur" "$TARGET/DOCTRINE.md" \
  && ck "DOCTRINE.md: aggregation rule present" "0" "0" || ck "DOCTRINE.md: aggregation rule" "present" "MISSING"
grep -q "auto-loads" "$TARGET/preset/$PRESET_DIR/src/behavior.ts" \
  && ck "behavior.ts: no instance-specific data-path sentence" "none" "still-present" \
  || ck "behavior.ts: no instance-specific data-path sentence" "0" "0"
grep -qiE "DOCTRINE_FILE|DOCTRINE\.md" "$TARGET/preset/$PRESET_DIR/src/behavior.ts" \
  && ck "behavior.ts: points at DOCTRINE" "0" "0" || ck "behavior.ts: DOCTRINE pointer" "present" "MISSING"

# --- 3. gates resolve + digest ------------------------------------------------
( cd "$TARGET" && bash 06_gates/verify_ledger.sh >/dev/null 2>&1 ); ck "verify_ledger resolves (brains.sh)" "0" "$?"
( cd "$TARGET" && bash state/memory/make_brief.sh >/dev/null 2>&1 ); ck "make_brief regenerates digest" "0" "$?"
[ -s "$TARGET/state/memory/BRIEF.md" ]; ck "BRIEF.md non-empty" "0" "$?"
# derive the real max ledger id (PADDED, as the gate expects), then assert boot stamp reads through it
MAXID="$(grep -oE '^\| B-[0-9]+ \|' "$TARGET/state/memory/beliefs.md" | grep -oE 'B-[0-9]+' | sort -t- -k2 -n | tail -1)"
bootout="$(cd "$TARGET" && echo "boot: $MAXID" | bash 06_gates/g10_preflight.sh 2>&1)"
echo "$bootout" | grep -q "BOOT OK"; ck "boot stamp $MAXID OK (max)" "0" "$?"

# --- 4. zero business strings in instance OWN content ------------------------
# '2026' excluded: it is the current-date timestamp in the digest, not domain content.
# The real leak markers are the domain terms (grossiste/BIOPURE/vecopharm/gdbc/...).
# Scans state/SPEC/AGENT_CORE/READ_FIRST/AGENTS/09_task_goals/Machinery/00_purpose PLUS
# the born-state Machinery files + tests/ (the generic conformance harness must stay domain-free).
hit="$(grep -rliE 'grossiste|BIOPURE|vecopharm|gdbc|ristourne|SIPHAL|FERRO|top_grossiste|pharmacie' \
       "$TARGET/state" "$TARGET/SPEC" "$TARGET/AGENT_CORE.md" "$TARGET/READ_FIRST.md" \
       "$TARGET/AGENTS.md" "$TARGET/09_task_goals" "$TARGET/Machinery/00_purpose" \
       "$TARGET/Machinery/cockpit" "$TARGET/Machinery/07_reports" "$TARGET/tests" 2>/dev/null || true)"
[ -z "$hit" ] && ck "no business strings in instance content" "0" "0" || { ck "no business strings" "clean" "LEAK: $hit"; }

# --- 5. no un-substituted placeholders ---------------------------------------
# {{model}}/{{cwd}} (persona) and {{date}} (brief template) are intentional template vars.
ph="$(grep -rn '{{' "$TARGET" 2>/dev/null | grep -v '{{model}}\|{{cwd}}\|{{date}}' || true)"
[ -z "$ph" ] && ck "no un-substituted placeholders" "0" "0" || { ck "placeholders" "none" "FOUND: $ph"; }

# --- 6. gate regression harness runs -----------------------------------------
( cd "$TARGET" && bash tests/test_gate.sh >/dev/null 2>&1 ); ck "gate harness (test_gate.sh) 7/7" "0" "$?"

# --- 7. new rules present (SPEC read-order + output-shape rule) --------------
grep -qiE 'SPEC/01\.\.05|SPEC/0[1-5]' "$TARGET/AGENT_CORE.md" "$TARGET/AGENTS.md" 2>/dev/null \
  && ck "SPEC in read-order" "0" "0" || ck "SPEC in read-order" "present" "MISSING"
grep -qiE 'never dump|raw list|> ~10 rows|Shape of the reply|Forme de la réponse' "$TARGET/AGENT_CORE.md" 2>/dev/null \
  && ck "output-shape rule" "0" "0" || ck "output-shape rule" "present" "MISSING"

# --- 8. core_check runs on the generated instance (must be healthy) -----------
if [ -f "$TARGET/core_check.sh" ]; then
  ( cd "$TARGET" && bash core_check.sh >/dev/null 2>&1 ); rc=$?
  ck "core_check.sh HEALTHY (exit 0)" "0" "$rc"
fi


# --- 9. spec contract: the functional spec must be coherent (generate + test the spec) --------
  bash "$DIR/spec_check.sh" >/dev/null 2>&1; ck "spec_check.sh coherent" "0" "$?"
  if bash "$DIR/spec_gen.sh" generate /tmp/spec_index_check.json >/dev/null 2>&1 && [ -s /tmp/spec_index_check.json ]; then rm -f /tmp/spec_index_check.json; ck "spec_gen generates index" "0" "0"; else ck "spec_gen generates index" "0" "1"; fi

# --- 9b. BEHAVIORAL: the generated preset engine must be LIVE (not the dead load/ctx.add variant).
# This is the check that catches the "dead plugin" defect — a template behavior.ts that exports
# load(ctx)/ctx.add() produces no persona/core/memory/tool, yet passes a presence-only test.
BT="$(find "$TARGET/preset" -name behavior.ts 2>/dev/null | head -1)"
if [ -n "$BT" ]; then
  grep -qE "export const inject" "$BT" && grep -qE "export function apply" "$BT" \
    && grep -qE "ctx\.systemPrompt\.section" "$BT" && grep -qE "output:\s*\{|\"schema\"" "$BT" \
    && ck "behavior.ts live contract (inject/apply/section/output)" "0" "0" \
    || ck "behavior.ts live contract" "live" "DEAD (load/ctx.add present)"
  # no broken-API remnants
  if grep -qE "export function load|ctx\.add\(|additionalProperties: false" "$BT"; then
    ck "behavior.ts no dead-API remnants" "0" "1"
  else
    ck "behavior.ts no dead-API remnants" "0" "0"
  fi
else
  ck "behavior.ts present in preset" "present" "MISSING"
fi

# --- 9c. STRUCTURAL: S-01..S-10 must be STRUCTURAL surfaces (match AGENT_CORE §0b), never data ids.
# A data-entity register (S-01=wholesaler) collides with the self-model (S-01=AGENT_CORE).
if [ -f "$TARGET/state/architecture.md" ]; then
  if grep -qE "S-01.*AGENT_CORE" "$TARGET/state/architecture.md" \
     && grep -qE "S-10.*cockpit|Cockpit" "$TARGET/state/architecture.md"; then
    ck "architecture S-01..S-10 structural (= §0b)" "0" "0"
  else
    ck "architecture S-01..S-10 structural (= §0b)" "structural" "COLLISION (data ids)"
  fi
else
  ck "architecture register present" "0" "1"
fi

# --- 9d. GENERIC GATE: the universal gate driver ships + AGENT_CORE mandates it (no domain bypass).
# A calculation (coverage, rupture, rank, sum...) must go through g_gate_deliverable.sh → it must
# exist in the shipped 06_gates AND AGENT_CORE must reference it.
if [ -f "$TARGET/06_gates/g_gate_deliverable.sh" ]; then
  ck "generic gate driver ships (g_gate_deliverable.sh)" "0" "0"
else
  ck "generic gate driver ships (g_gate_deliverable.sh)" "present" "MISSING"
fi
grep -qE "g_gate_deliverable|Gate GÉNÉRIQUE|aucune exemption" "$TARGET/AGENT_CORE.md" 2>/dev/null \
  && ck "AGENT_CORE generic-gate mandate" "0" "0" \
  || ck "AGENT_CORE generic-gate mandate" "present" "MISSING"

# --- 9e. PURPOSE SENSING (A5): the loop must enforce purpose — runtime persona + AGENT_CORE.
# A calculation with no mission-citation / drift-escalate is purpose-blind (the loop gap).
if [ -n "$BT" ]; then
  grep -qiE "Purpose sensing|name which mission|drift" "$BT" \
    && ck "behavior.ts purpose sensing (A5)" "0" "0" \
    || ck "behavior.ts purpose sensing (A5)" "present" "MISSING"
fi
grep -qiE "GRASP.*mission|name the mission|confirme.*mission|purpose" "$TARGET/AGENT_CORE.md" 2>/dev/null \
  && ck "AGENT_CORE purpose step (A5)" "0" "0" \
  || ck "AGENT_CORE purpose step (A5)" "present" "MISSING"

# --- 9f. MECHANICAL LOOP VERIFIER: verify_loop.sh ships + refuses a bad trace (software proof).
if [ -f "$TARGET/06_gates/verify_loop.sh" ]; then
  ck "verify_loop.sh ships" "0" "0"
else
  ck "verify_loop.sh ships" "present" "MISSING"
fi
grep -qE "verify_loop|LOOP TRACE" "$TARGET/AGENT_CORE.md" 2>/dev/null \
  && ck "AGENT_CORE loop-trace mandate" "0" "0" \
  || ck "AGENT_CORE loop-trace mandate" "present" "MISSING"

# --- 9g. ENGINE-FREE LOOP (guard_loop): the loop-forcer ships + the gate driver supports --verify-same.
if [ -f "$TARGET/06_gates/guard_loop.sh" ]; then
  ck "guard_loop.sh ships (engine-free loop)" "0" "0"
else
  ck "guard_loop.sh ships (engine-free loop)" "present" "MISSING"
fi
[ -f "$TARGET/API/report_map.json" ] && ck "report_map.json (data-driven map)" "0" "0" \
  || ck "report_map.json (data-driven map)" "present" "MISSING"
grep -qE "verify-same" "$TARGET/06_gates/g_gate_deliverable.sh" 2>/dev/null \
  && ck "gate driver --verify-same (relecture stability)" "0" "0" \
  || ck "gate driver --verify-same" "present" "MISSING"
grep -qE "guard_loop|sans moteur dédié|report_map" "$TARGET/AGENT_CORE.md" 2>/dev/null \
  && ck "AGENT_CORE engine-free loop doctrine" "0" "0" \
  || ck "AGENT_CORE engine-free loop doctrine" "present" "MISSING"

# --- 9h. SINGLE DELIVERY PATH + CONFORMANCE HARNESS (the C26/G7 evolution) ---
for f in livrer.sh loop.sh; do
  [ -f "$TARGET/06_gates/$f" ] && ck "06_gates/$f ships" "0" "0" || ck "06_gates/$f ships" "present" "MISSING"
done
for f in tests/convention.sh tests/convention_observe.py tests/convention_cases.json; do
  [ -f "$TARGET/$f" ] && ck "$f ships" "0" "0" || ck "$f ships" "present" "MISSING"
done
grep -qE "livrer\.sh|relecture" "$TARGET/AGENT_CORE.md" 2>/dev/null \
  && ck "AGENT_CORE single-delivery-path doctrine" "0" "0" \
  || ck "AGENT_CORE single-delivery-path doctrine" "present" "MISSING"
# the conformance CASES must be domain-free (no GDBC golden totals / snapshot labels)
grep -qiE 'grossiste|BIOPURE|vecopharm|pharmacie|top_grossiste|Desktop-GDBC' "$TARGET/tests/convention_cases.json" 2>/dev/null \
  && ck "convention_cases.json domain-free" "clean" "LEAK" \
  || ck "convention_cases.json domain-free" "0" "0"

# --- 10. SPEC-COMPLIANCE: the shipped spec IS the canonical spec + the born-state audit reconciles ---
# 10a. One spec lineage: the instance ships the canonical spec byte-for-byte (no second, drifting copy).
if [ -f "$DIR/AGENT_SPEC.md" ] && [ -f "$TARGET/AGENT_SPEC.md" ]; then
  if cmp -s "$DIR/AGENT_SPEC.md" "$TARGET/AGENT_SPEC.md"; then
    ck "shipped spec == canonical (no second lineage)" "0" "0"
  else
    ck "shipped spec == canonical" "identical" "DRIFT"
  fi
else
  ck "spec present both sides" "present" "MISSING"
fi
# 10b. The spec-conformance audit ships born-state and RECONCILES (catalog ↔ coverage).
if [ -s "$TARGET/tests/spec_catalog.json" ] && [ -s "$TARGET/tests/spec_coverage.json" ]; then
  rec="$(python3 - "$TARGET/tests/spec_catalog.json" "$TARGET/tests/spec_coverage.json" <<'PY'
import json, sys
cat = json.load(open(sys.argv[1], encoding='utf8'))
cov = json.load(open(sys.argv[2], encoding='utf8'))
MAP = {'covered':'conform','partial':'partiel','todo':'todo','absent':'absent','manquant':'absent','na':'na'}
c = {'conform':0,'partiel':0,'todo':0,'absent':0,'na':0}
bad = []
for f in cat.get('functions', []):
    st = str(f.get('status','todo')).strip().lower()
    if st not in MAP: bad.append(st); continue
    c[MAP[st]] += 1
tot = len(cat.get('functions', []))
ok = (not bad) and sum(c.values()) == tot and cov.get('total') == tot \
     and all(cov.get(k, 0) == c[k] for k in c)
print("OK" if ok else f"BAD(catalog={c} total={tot} coverage={cov} vocab={sorted(set(bad))})")
PY
)"
  [ "$rec" = "OK" ] && ck "spec catalog<->coverage reconcile" "0" "0" || ck "spec catalog<->coverage reconcile" "OK" "$rec"
else
  ck "spec catalog+coverage ship born-state" "present" "MISSING"
fi
# 10c. The cockpit /spec route has both files it reads (else it 500s on every fresh instance).
[ -s "$TARGET/tests/spec_catalog.json" ] && [ -s "$TARGET/tests/spec_coverage.json" ] \
  && ck "cockpit /spec route resolvable" "0" "0" || ck "cockpit /spec route resolvable" "present" "MISSING"
# 10d. The world-class test ships as a generic skeleton + runner (G9).
[ -s "$TARGET/tests/world_class_test.json" ] && [ -f "$TARGET/tests/world_class_run.py" ] \
  && ck "world-class skeleton + runner ship (G9)" "0" "0" || ck "world-class skeleton + runner" "present" "MISSING"
# 10e. SPEC ↔ INSTANCE PARITY (the derived check): every artifact AGENT_SPEC.md NAMES must exist in
#      the GENERATED instance. A spec entry naming a file forces the template to ship it.
if [ -f "$DIR/spec_parity.py" ]; then
  pout="$(python3 "$DIR/spec_parity.py" --instance "$TARGET" 2>&1)"; prc=$?
  if [ "$prc" = "0" ]; then
    ck "spec↔instance parity ($(printf '%s' "$pout" | head -1 | sed 's/.*: //'))" "0" "0"
  else
    ck "spec↔instance parity" "all-resolve" "$(printf '%s' "$pout" | grep MISSING | head -3 | tr '\n' ';')"
  fi
else
  ck "spec_parity.py present" "present" "MISSING"
fi

rm -rf "$TMP"
echo "=== RESUME GENERATOR: $PASS PASS, $FAIL FAIL ==="
[ "$FAIL" -eq 0 ]
