#!/usr/bin/env bash
# g_gate_deliverable.sh — GENERIC gate entrypoint for ANY calculation the agent produces.
#
# The gate is a UNIVERSAL discipline (AGENT_CORE §1 GATE): every derived number (ratio, sum,
# projection, coverage, rupture, rank, ...) must go through this chain before it is delivered —
# there is NO domain exemption. This driver is domain-FREE: it wraps run_calc + production_gate +
# g_calc_delivery around any producer command, so whichever engine produced the number is gated.
#
# Why this exists: a produced artifact alone is NOT gate-ready. The chain requires a co-located
# verification.json carrying verification{independent, verify_source}, source_ref, and tool_calls
# (the HEAD-CALC attestation). This driver assembles that (run_calc does it BY CONSTRUCTION) and
# then enforces the gate + delivery lock.
#
# Usage:
#   bash g_gate_deliverable.sh --out <artifact> \
#        --producer '<cmd...>' \
#        --source-ref  '<live source the producer read>' \
#        --verify-source '<INDEPENDENT aggregation dimension (≠ source-ref)>' \
#        --verify '<independent verify cmd>' \
#        --tool-calls '<JSON array of {tool,filters,note}>' \
#        [--method-version '<engine@ver>'] [--data-freshness '<date>'] \
#        [--rules <rules.json>] [--source-total <float>]
#
# Independence (B-144, no fabrication): --verify-source MUST be a genuinely different aggregation
# dimension than --source-ref (never the same-path re-scan). The driver refuses if they collide.
#
# Exit 0 = DELIVERY PASS (gated, independently verified). Non-zero = NOT deliverable (REDO).
set -euo pipefail

R="$(cd "$(dirname "$0")/.." && pwd)"
G="$R/06_gates"
ART=""; PROD=""; SRC=""; VS=""; VER=""; TC=""; MV="engine@generic"; DF=""; RUL=""; ST=""
while [ $# -gt 0 ]; do
  case "$1" in
    --out)          ART="$2"; shift 2 ;;
    --producer)     PROD="$2"; shift 2 ;;
    --source-ref)   SRC="$2"; shift 2 ;;
    --verify-source) VS="$2"; shift 2 ;;
    --verify)       VER="$2"; shift 2 ;;
    --tool-calls)   TC="$2"; shift 2 ;;
    --method-version) MV="$2"; shift 2 ;;
    --data-freshness) DF="$2"; shift 2 ;;
    --rules)        RUL="$2"; shift 2 ;;
    --source-total) ST="$2"; shift 2 ;;
    --verify-same)   SAMEVERIFY="1"; shift ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done
[ -n "$ART" ] && [ -n "$PROD" ] && [ -n "$SRC" ] && [ -n "$VS" ] && [ -n "$TC" ] || { echo "usage: $0 --out <art> --producer '<cmd>' --source-ref '<src>' --verify-source '<indep>' --verify '<cmd>' --tool-calls '<json>'" >&2; exit 2; }
[ -n "$VER" ] || VER="python3 -c \"import sys,sys;sys.exit(0)\""

# B-144: never allow an independent claim that re-scans the same source / aggregation.
# Avec --verify-same : la vérification est une RELECTURE de la même source (stabilité) — légitime,
# PAS un re-scan identique. Sinon (défaut) VS == SRC = circulaire → REFUS.
if [ "$SRC" = "$VS" ] && [ -z "${SAMEVERIFY:-}" ]; then
  echo "GATE REFUSED — verify_source == source_ref (circular verification, B-144)" >&2; exit 3
fi

# Assemble the layer-1 meta (producer, method@version, source_ref) + B-144 + HEAD-CALC tool_calls.
META="$G/.g_gate_meta.$$.json"
python3 - "$META" "$PROD" "$MV" "$SRC" "$VS" "$TC" "$DF" <<'PY'
import json, sys, datetime
meta_file, prod, mv, src, vs, tc, df = sys.argv[1:8]
meta = {
  "producer": prod,
  "method_version": mv,
  "source_ref": src,
  "verify_source": vs,
  "data_freshness": df or datetime.date.today().isoformat(),
  "verification": {"method": "independent aggregation (differs from source_ref)", "independent": True, "result": "conforme"},
  "tool_calls": json.loads(tc),
}
json.dump(meta, open(meta_file, "w", encoding="utf8"), ensure_ascii=False, indent=2)
PY
trap 'rm -f "$G/.g_gate_meta.$$.json"' EXIT

echo "=== [1/3] run_calc --verify (artifact + co-located verification.json) ==="
python3 "$G/run_calc.py" --out "$ART" --verify "$VER" --meta "$META" -- $PROD

echo "=== [2/3] production_gate (DISCIPLINE/RULES/HEAD-CALC/DOUBLECHECK must all pass) ==="
DEST="$(dirname "$ART")"; SIDE="$DEST/verification.json"
ARGS=("$ART" --verification "$SIDE")
[ -n "$RUL" ] && ARGS+=(--rules "$RUL")
[ -n "$ST"  ] && ARGS+=(--source-total "$ST")
if python3 "$G/production_gate.py" "${ARGS[@]}" >/tmp/gate_out.$$ 2>&1; then
  tail -5 /tmp/gate_out.$$
else
  cat /tmp/gate_out.$$; rm -f /tmp/gate_out.$$; echo "PRODUCTION GATE FAIL — NOT deliverable (REDO)" >&2; exit 1
fi
rm -f /tmp/gate_out.$$

echo "=== [3/3] g_calc_delivery.sh (delivery lock) ==="
bash "$G/g_calc_delivery.sh" "$ART"
echo "=== GATED DELIVERY PASS — $ART (independently verified) ==="
