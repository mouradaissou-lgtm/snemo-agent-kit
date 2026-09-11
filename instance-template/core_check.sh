#!/usr/bin/env bash
# core_check.sh — universal standalone-instance self-check (the "is the agent working?" command).
#
# Run from an instance root (or pass --root). It reports a PASS/FAIL/NA matrix across the
# 9 functional groups of AGENT_SPEC.md, mechanically, with evidence. Generic by construction:
# no domain vocabulary; parameterized only by the instance root.
#
# Usage:
#   bash core_check.sh [--root <path>] [--full] [--json]
#     --root   instance root (default = the directory containing this script's parent or cwd)
#     --full   add live-data checks (needs a token / data doctrine; slow)
#     --json   machine-readable (single line with counts)
# Exit 0 = healthy (no FAIL), 1 = at least one FAIL.
#
# POSIX-bash + python3 only (no deps), so ANY instance can run it.

set -u
ROOT="$(pwd)"
FULL=0; JSON=0
while [ $# -gt 0 ]; do
  case "$1" in
    --root) ROOT="$2"; shift 2 ;;
    --full) FULL=1; shift ;;
    --json) JSON=1; shift ;;
    *) shift ;;
  esac
done

# If running INSIDE an instance's core_check.sh (not the template), root already = instance.
# The template ships at <instance>/core_check.sh; if run from elsewhere, allow --root.
if [ -f "$ROOT/../AGENT_CORE.md" ] && [ -f "$ROOT/../state/memory/beliefs.md" ]; then
  ROOT="$(cd "$ROOT/.." && pwd)"
fi

PASS=0; FAIL=0; NA=0
g_fail=""
ck() {  # ck <group> <check> <0=pass|1=fail|2=na> <evidence...>
  local grp="$1" name="$2" st="$3"; shift 3
  if [ "$st" = "0" ]; then PASS=$((PASS+1));
  elif [ "$st" = "1" ]; then FAIL=$((FAIL+1)); g_fail="$g_fail$grp/$name\n";
  else NA=$((NA+1)); fi
  printf '  %-3s %-42s %s\n' "$grp" "$name" "$([ "$st" = 0 ] && echo PASS || { [ "$st" = 2 ] && echo '  NA  ' || echo 'FAIL '; })"
}
have() { [ -e "$ROOT/$1" ]; }
have_d() { [ -d "$ROOT/$1" ]; }

echo "=== INSTANCE SELF-CHECK — root: $ROOT ==="

# ---------------------------------------------------------------- U1 identity/wiring
g="U1"; s=0
have AGENT_CORE.md && ck "$g" "front door AGENT_CORE" 0 || ck "$g" "front door AGENT_CORE" 1
grep -q 'STRUCTURE\|structure' "$ROOT/AGENT_CORE.md" 2>/dev/null && ck "$g" "self-architecture §0b" 0 || ck "$g" "self-architecture §0b" 1
have AGENTS.md && ck "$g" "workspace pointer AGENTS.md" 0 || ck "$g" "workspace pointer AGENTS.md" 1
grep -q 'Ledger max id' "$ROOT/AGENTS.md" 2>/dev/null && ck "$g" "digest embedded" 0 || ck "$g" "digest embedded" 1
have READ_FIRST.md && ck "$g" "read-first list" 0 || ck "$g" "read-first list" 1
# SPEC files
SPECOK=1; for i in 01 02 03 04 05; do [ "$(ls "$ROOT/SPEC/${i}_"*.md 2>/dev/null | wc -l)" -ge 1 ] || SPECOK=0; done
[ "$SPECOK" = 1 ] && ck "$g" "SPEC/01..05 present" 0 || ck "$g" "SPEC/01..05 present" 1
# SPEC in boot read-order (AGENT_CORE §2 or AGENTS.md)
grep -qiE 'SPEC/01\.\.05|SPEC/0[1-5]' "$ROOT/AGENT_CORE.md" "$ROOT/AGENTS.md" 2>/dev/null && ck "$g" "SPEC in read-order" 0 || ck "$g" "SPEC in read-order" 1
# preset folder present (named or flat)
ls "$ROOT/preset/" >/dev/null 2>&1 && ck "$g" "preset folder" 0 || ck "$g" "preset folder" 1

# ---------------------------------------------------------------- U2 memory
g="U2"
[ -f "$ROOT/state/memory/MODE" ] && ck "$g" "MODE toggle" 0 || ck "$g" "MODE toggle" 1
LED="$ROOT/state/memory/beliefs.md"
if [ -f "$LED" ]; then
  grep -q '^| id | type | content' "$LED" && ck "$g" "ledger header" 0 || ck "$g" "ledger header" 1
  dups=$(grep -oE '^\| B-[0-9]+ \|' "$LED" | tr -d ' |' | sort | uniq -d)
  [ -z "$dups" ] && ck "$g" "ledger unique ids" 0 || ck "$g" "ledger unique ids (dups: $dups)" 1
else
  ck "$g" "ledger present" 1
fi
[ -f "$ROOT/state/memory/facts.md" ] && ck "$g" "fact bank" 0 || ck "$g" "fact bank" 1
grep -q 'CONTRADICTIONS' "$LED" 2>/dev/null && ck "$g" "contradiction protocol" 0 || ck "$g" "contradiction protocol" 1
grep -q 'FORGET LIST' "$LED" 2>/dev/null && ck "$g" "forget list" 0 || ck "$g" "forget list" 1
# gate doctrines self-contained + core-cited (any B-01x doctrine with 'cœur B-1' provenance)
cor=$(grep -E '^\| B-0[0-9]+ \| doctrine \|' "$LED" 2>/dev/null | grep -c 'cœur B-1')
[ "$cor" -gt 0 ] && ck "$g" "gate doctrines core-cited ($cor)" 0 || ck "$g" "gate doctrines core-cited" 2

# ---------------------------------------------------------------- U3 gates run
g="U3"
for gl in verify_ledger verify_numbers verify_evidence verify_logs check_graph; do
  if [ -f "$ROOT/06_gates/$gl.sh" ]; then bash "$ROOT/06_gates/$gl.sh" >/dev/null 2>&1 && ck "$g" "$gl" 0 || ck "$g" "$gl" 1; else ck "$g" "$gl" 2; fi
done
# boot stamp on the real max id (keep the PADDED id — the gate greps the ledger's padded form)
if [ -f "$ROOT/06_gates/g10_preflight.sh" ]; then
  maxid=$(grep -oE '^\| B-[0-9]+ \|' "$LED" 2>/dev/null | grep -oE 'B-[0-9]+' | sort -t- -k2 -n | tail -1)
  echo "boot: $maxid" | bash "$ROOT/06_gates/g10_preflight.sh" >/dev/null 2>&1 && ck "$g" "boot stamp ($maxid)" 0 || ck "$g" "boot stamp ($maxid)" 1
fi
# g11 instance-correct (no hardcoded GBC path in the gate)
if [ -f "$ROOT/06_gates/g11_architecture_sync.sh" ]; then
  grep -q '/Users/mouradaissou/GBC' "$ROOT/06_gates/g11_architecture_sync.sh" && ck "$g" "g11 no hardcoded GBC" 1 || ck "$g" "g11 no hardcoded GBC" 0
  ( cd "$ROOT" && ARCH_BRAIN="$ROOT" ARCH_REG="$ROOT/state/architecture.md" bash 06_gates/g11_architecture_sync.sh >/dev/null 2>&1 ) && ck "$g" "g11 sync (instance)" 0 || ck "$g" "g11 sync (instance)" 1
else
  ck "$g" "g11 present" 2
fi
# python gates present
for gp in production_gate provenance_gate run_calc g_calc g_livraison_verif schema_profile; do
  [ -f "$ROOT/06_gates/$gp.py" ] && ck "$g" "$gp.py present" 0 || ck "$g" "$gp.py present" 2
done
# provenance selftest
if [ -f "$ROOT/06_gates/provenance_gate.py" ]; then
  n=$(python3 "$ROOT/06_gates/provenance_gate.py" --selftest 2>&1 | grep -cE 'OK|✓'); [ "$n" -ge 5 ] && ck "$g" "provenance selftest ($n)" 0 || ck "$g" "provenance selftest" 1
fi
# generic gate driver present (gate ANY calculation; no domain bypass)
[ -f "$ROOT/06_gates/g_gate_deliverable.sh" ] && ck "$g" "generic gate driver (g_gate_deliverable.sh)" 0 || ck "$g" "generic gate driver" 1
# loop verifier present + self-check (mechanical check that the loop is walked step-by-step)
if [ -f "$ROOT/06_gates/verify_loop.sh" ]; then
  LT="/tmp/loop_sc.$$.json"
  printf '{"artifact":"a.json","mission":"m","steps":["grasp","judge","sharpen","pre_vol","propose","jump","gate","learn"],"params":{"grasp":{},"judge":{},"sharpen":{},"pre_vol":{"purpose_ok":true},"propose":{},"jump":{"kind":"proposal"},"gate":{"verdict":"PASS"},"learn":{"written_back":"x"}}}' > "$LT"
  bash "$ROOT/06_gates/verify_loop.sh" "$LT" >/dev/null 2>&1 && ck "$g" "verify_loop (valid trace=pass)" 0 || ck "$g" "verify_loop (valid trace=pass)" 2
  printf '{"artifact":"a.json","mission":"","steps":["grasp","jump"],"params":{"grasp":{},"jump":{}}}' > "$LT"
  bash "$ROOT/06_gates/verify_loop.sh" "$LT" >/dev/null 2>&1 && ck "$g" "verify_loop (bad trace=refuse)" 1 || ck "$g" "verify_loop (bad trace=refuse)" 0
  rm -f "$LT"
else
  ck "$g" "verify_loop" 1
fi
# engine-free loop (guard_loop) + report_map + gate --verify-same — the backported evolution.
[ -f "$ROOT/06_gates/guard_loop.sh" ] && ck "$g" "engine-free loop (guard_loop.sh)" 0 || ck "$g" "engine-free loop" 1
[ -f "$ROOT/API/report_map.json" ] && ck "$g" "report_map.json (data-driven map)" 0 || ck "$g" "report_map.json" 1
grep -qE "verify-same" "$ROOT/06_gates/g_gate_deliverable.sh" 2>/dev/null \
  && ck "$g" "gate --verify-same (relecture stability)" 0 || ck "$g" "gate --verify-same" 1
# single delivery path + loop initializer + conformance harness (the C26/G7 evolution).
[ -f "$ROOT/06_gates/livrer.sh" ] && ck "$g" "single delivery path (livrer.sh)" 0 || ck "$g" "single delivery path" 1
[ -f "$ROOT/06_gates/loop.sh" ] && ck "$g" "loop initializer (loop.sh)" 0 || ck "$g" "loop initializer" 1
[ -f "$ROOT/tests/convention.sh" ] \
  && ck "$g" "conformance harness (convention.sh)" 0 || ck "$g" "conformance harness" 1

# ---------------------------------------------------------------- U4 structure
g="U4"
[ -f "$ROOT/state/architecture.md" ] && ck "$g" "architecture register" 0 || ck "$g" "architecture register" 1
[ -d "$ROOT/09_task_goals" ] && ck "$g" "task-goal system" 0 || ck "$g" "task-goal system" 1
for lf in DECISION_LOG DECISION_QUEUE ROUND_LOG; do [ -f "$ROOT/Machinery/03_logs/$lf.md" ] && ck "$g" "$lf" 0 || ck "$g" "$lf" 1; done
[ -d "$ROOT/Machinery/02_framework" ] && ck "$g" "machinery framework" 0 || ck "$g" "machinery framework" 1
# G1/G2/G3 born-state capability surfaces (must ship in every instance): cockpit + reports + contract.
[ -f "$ROOT/Machinery/cockpit/dashboard_server.js" ] && [ -f "$ROOT/Machinery/cockpit/dashboard.html" ] && [ -f "$ROOT/Machinery/cockpit/monitor.py" ] \
  && ck "$g" "cockpit (G1: server+dashboard+monitor)" 0 || ck "$g" "cockpit (G1)" 1
[ -f "$ROOT/Machinery/07_reports/serve_deliverables.py" ] && [ -f "$ROOT/Machinery/07_reports/update_deliverables_index.py" ] \
  && ck "$g" "reports server (G2)" 0 || ck "$g" "reports server (G2)" 1
[ -f "$ROOT/Machinery/02_framework/AGENT_CORE_machinery_contract.md" ] \
  && ck "$g" "machinery contract (G3)" 0 || ck "$g" "machinery contract (G3)" 1
# G8/G9 born-state: spec-conformance audit (catalog+coverage reconciling) + world-class skeleton/runner.
[ -s "$ROOT/tests/spec_catalog.json" ] && [ -s "$ROOT/tests/spec_coverage.json" ] \
  && ck "$g" "spec-conformance audit ships (G8)" 0 || ck "$g" "spec-conformance audit (G8)" 1
rec="$(python3 - "$ROOT/tests/spec_catalog.json" "$ROOT/tests/spec_coverage.json" <<'PY' 2>/dev/null
import json, sys
MAP = {'covered':'conform','partial':'partiel','todo':'todo','absent':'absent','manquant':'absent','na':'na'}
try:
    cat = json.load(open(sys.argv[1], encoding='utf8')); cov = json.load(open(sys.argv[2], encoding='utf8'))
except Exception as e:
    print("BAD(load)"); raise SystemExit
c = {'conform':0,'partiel':0,'todo':0,'absent':0,'na':0}
bad = []
for f in cat.get('functions', []):
    st = str(f.get('status','todo')).strip().lower()
    if st not in MAP: bad.append(st); continue
    c[MAP[st]] += 1
tot = len(cat.get('functions', []))
ok = (not bad) and sum(c.values()) == tot and cov.get('total') == tot and all(cov.get(k,0) == c[k] for k in c)
print("OK" if ok else f"BAD(total={tot} cov={cov})")
PY
)"
[ "$rec" = "OK" ] && ck "$g" "spec catalog<->coverage reconcile" 0 || ck "$g" "spec catalog<->coverage reconcile (${rec:-none})" 1
[ -s "$ROOT/tests/world_class_test.json" ] && [ -f "$ROOT/tests/world_class_run.py" ] \
  && ck "$g" "world-class skeleton+runner (G9)" 0 || ck "$g" "world-class skeleton+runner (G9)" 1

# ---------------------------------------------------------------- U5 data (needs doctrine/token else NA)
g="U5"
# Dépend du grounding de l'instance : moteur = {{TOOL_FILE}} (API/<name>_api.py), token = API/token.txt.
ENG="$(basename "{{TOOL_FILE}}")"
if [ "$FULL" = 1 ]; then
  if [ -f "$ROOT/API/$ENG" ]; then
    TOK=$(cat "$ROOT/API/token.txt" 2>/dev/null | tr -d '[:space:]')
    if [ -n "${TOK:-}" ]; then
      R0=$(python3 -c "import json,sys;d=json.load(open('$ROOT/API/report_map.json'));ks=[k for k in d if not k.startswith('_')];print(ks[0] if ks else '')" 2>/dev/null)
      for R in "${R0:-sample}"; do
        v=$(cd "$ROOT/API" && API_TOKEN="$TOK" python3 "$ENG" count "$R" 2>/dev/null | python3 -c "import json,sys;print(json.load(sys.stdin).get('totalElements'))" 2>/dev/null)
        [ -n "$v" ] && [ "$v" != "None" ] && ck "$g" "count $R ($v)" 0 || ck "$g" "count $R" 2
      done
    else
      ck "$g" "data (grounding: token absent)" 2
    fi
  else
    ck "$g" "data (grounding: engine $ENG absent)" 2
  fi
else
  ck "$g" "data (--full)" 2
fi

# ---------------------------------------------------------------- U6 behavior/voice
g="U6"
grep -qiE 'audience|calibrated voice' "$ROOT/AGENT_CORE.md" 2>/dev/null && ck "$g" "audience rule" 0 || ck "$g" "audience rule" 1
grep -qiE 'never dump|raw list|> ~10 rows|Shape of the reply|Forme de la réponse' "$ROOT/AGENT_CORE.md" 2>/dev/null && ck "$g" "output-shape rule" 0 || ck "$g" "output-shape rule" 1
grep -qE 'Forbidden:.*raw tables|raw tables' "$ROOT/SPEC/05_WRITING_STYLE.md" 2>/dev/null && ck "$g" "SPEC/05 chat rule" 0 || ck "$g" "SPEC/05 chat rule" 2
# Purpose sensing (A5): the loop must enforce purpose — GRASP names the mission, PRÉ-VOL re-confirms.
grep -qiE 'GRASP.*mission|name the mission|nomme la mission|confirme.*mission|purpose' "$ROOT/AGENT_CORE.md" 2>/dev/null \
  && ck "$g" "purpose sensing (A5)" 0 || ck "$g" "purpose sensing (A5)" 1

# ---------------------------------------------------------------- U7 self
g="U7"
[ -f "$ROOT/tests/test_gate.sh" ] && ( cd "$ROOT" && bash tests/test_gate.sh >/dev/null 2>&1 ) && ck "$g" "gate harness 7/7" 0 || ck "$g" "gate harness" 1
# no un-substituted placeholders (except intentional template vars)
ph=$(grep -rn '{{' "$ROOT" --include='*.md' --include='*.ts' --include='*.yml' 2>/dev/null | grep -v '{{model}}\|{{cwd}}\|{{date}}' | head -1)
[ -z "$ph" ] && ck "$g" "no un-substituted placeholders" 0 || ck "$g" "no placeholders (${ph:0:40})" 1
# no business-content leak — but ONLY in the GENERIC files (the register/state legitimately
# carry the domain's own labels; a standalone instance SHOULD name its domain there).
# Extends to tests/ + the new born-state Machinery files, so the domain never leaks into the
# generic conformance harness or the cockpit/reports contracts.
deny="GBC API|SNemo Demo|CEO of Zsoft|SNemo agent copy|chart\.py|grossiste|BIOPURE|vecopharm|top_grossiste|pharmacie|Desktop-GDBC|Desktop/GDBC|gdbc_api|snemo-gdbc-api|<instance>/deliverables"
leak=$(grep -riE "$deny" "$ROOT/AGENT_CORE.md" "$ROOT/AGENTS.md" "$ROOT/SPEC" "$ROOT/Machinery/02_framework" "$ROOT/Machinery/cockpit" "$ROOT/Machinery/07_reports" "$ROOT/tests" 2>/dev/null \
  | grep -viE 'the user|instance|CEO.*one concrete use case|SNemo agent copy is|ne PAS l. utiliser pour|DO NOT|NOT .(use|connect)|don.t|POUR .*GDBC|n.est pas|identit. .(SNemo|GDBC)|porte l.identit.|<instance>/deliverables' | head -1)
[ -z "$leak" ] && ck "$g" "no generic-file leak" 0 || ck "$g" "no generic-file leak (${leak:0:40})" 1

# ---------------------------------------------------------------- verdict
echo
echo "=== VERDICT: $PASS PASS / $FAIL FAIL / $NA NA ==="
if [ "$FAIL" -gt 0 ]; then
  echo "NOT HEALTHY — $FAIL check(s) failed:"
  printf "$g_fail" | sed 's/^/   /' | sort -u
  if [ "$JSON" = 1 ]; then
    # JSON emit via json.dumps: a hand-rolled sed/printf array produced INVALID JSON whenever a
    # check name carried a quote or a second '/', breaking every consumer (cockpit, tracker).
    FL="$(mktemp)"; printf "$g_fail" > "$FL"
    python3 - "$FL" "$PASS" "$FAIL" "$NA" <<'PY'
import json, sys
rows = [l.strip() for l in open(sys.argv[1], encoding="utf8") if l.strip()]
fails = sorted({r.replace("/", " ", 1) for r in rows})
print(json.dumps({"pass": int(sys.argv[2]), "fail": int(sys.argv[3]),
                  "na": int(sys.argv[4]), "healthy": False, "fails": fails},
                 ensure_ascii=False))
PY
    rm -f "$FL"
  fi
else
  echo "HEALTHY — all checks green."
  if [ "$JSON" = 1 ]; then printf '{"pass":%d,"fail":%d,"na":%d,"healthy":true}\n' "$PASS" "$FAIL" "$NA"; fi
fi
[ "$FAIL" -eq 0 ]
