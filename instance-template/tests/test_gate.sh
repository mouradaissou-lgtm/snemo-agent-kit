#!/usr/bin/env bash
# test_gate.sh — harnais de régression des gates de provenance (B-141/B-142/B-144/B-145/B-147).
# Outil de test. Auto-suffisant : make_fixture.py à côté, gate dans ../06_gates (ou $1).
# Usage: test_gate.sh [<provenance_gate.py>]   ; exit 0 si tout pass.
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"
GATE="${1:-$DIR/../06_gates/provenance_gate.py}"
GATE="$(cd "$(dirname "$GATE")" 2>/dev/null && pwd)/$(basename "$GATE")"
MF="$DIR/make_fixture.py"; [ -f "$MF" ] || MF=/tmp/make_fixture.py
FIX="$(mktemp -d /tmp/gate_fix.XXXXXX)"; FACTS="$FIX/facts.md"
python3 "$MF" "$FIX" >/dev/null
PASS=0; FAIL=0
ck(){ if [ "$2" = "$3" ]; then echo "  OK $1 ($2)"; PASS=$((PASS+1)); else echo "  XX $1 : attendu=$2 obtenu=$3"; FAIL=$((FAIL+1)); fi; }
echo "=== NIVEAU 1 : selftest ==="
N=$(python3 "$GATE" --selftest 2>&1 | grep -c "OK\|✓"); ck "selftest 5/5" "5" "$N"
echo "=== NIVEAU 3 : grille (fixtures syn.) ==="
rc=0; python3 "$GATE" --draft "$FIX/pos_live.md" --transcript "$FIX/t_live.jsonl" >/dev/null 2>&1 || rc=$?; ck "pos_live (source) -> PASS" "0" "$rc"
rc=0; python3 "$GATE" --draft "$FIX/pos_derived.md" --transcript "$FIX/t_live.jsonl" >/dev/null 2>&1 || rc=$?; ck "pos_derived (derive) -> PASS" "0" "$rc"
rc=0; python3 "$GATE" --draft "$FIX/neg_orphan.md" --transcript "$FIX/t_live.jsonl" >/dev/null 2>&1 || rc=$?; ck "neg_orphan -> FAIL" "2" "$rc"
rc=0; python3 "$GATE" --draft "$FIX/neg_claim.md" --transcript "$FIX/t_live.jsonl" >/dev/null 2>&1 || rc=$?; ck "neg_claim -> FAIL" "2" "$rc"
rc=0; python3 "$GATE" --draft "$FIX/neg_conflict.md" --transcript "$FIX/t_live.jsonl" --facts "$FACTS" --strict-b145 >/dev/null 2>&1 || rc=$?; ck "neg_conflict (strict-b145) -> FAIL" "2" "$rc"
rc=0; python3 "$GATE" --draft "$FIX/neg_reuse.md" --transcript "$FIX/t_reuse.jsonl" --no-reuse >/dev/null 2>&1 || rc=$?; ck "neg_reuse (--no-reuse) -> FAIL" "2" "$rc"
rm -rf "$FIX"
echo "=== RESUME : $PASS PASS, $FAIL FAIL ==="
[ "$FAIL" -eq 0 ]
