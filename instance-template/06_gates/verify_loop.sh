#!/usr/bin/env bash
# verify_loop.sh — MECHANICAL check that the agent walked the loop step by step (A1 loop + A5 purpose).
#
# The loop is Grasp → Judge → Sharpen → Pré-vol → PROPOSE → Jump → GATE → Learn. A numeric/derived
# deliverable must carry a loop-trace that proves it was walked in order AND that purpose (A5) was
# sensed (the mission is named in Grasp and confirmed in Pré-vol). The GATE stage is separately
# enforced by production_gate/provenance/g_calc_delivery; this gate verifies the STEPS, not the gate.
#
# Usage:
#   bash verify_loop.sh <loop-trace.json> [--artifact <path>]
# The trace is a JSON object with per-step fields (see the schema below). It MUST embed the mission
# ref (A5) and the artifact it produced. A trace with any missing/out-of-order step, or a bare number
# with no purpose-citation, is FAIL → the deliverable is REDO.
#
# Exit 0 = loop walked + purpose sensed. Exit 1 = FAIL (REDO). Exit 2 = usage/missing trace.
#
# Schema (loop-trace.json):
# {
#   "artifact": "<relative path of the gated deliverable>",
#   "mission":  "<mission/workstream/project this serves (A5 — required)",
#   "steps": ["grasp","judge","sharpen","pre_vol","propose","jump","gate","learn"],
#   "params": {
#     "grasp":   {"audience": "...", "objective": "..."},
#     "judge":   {"depth": "shallow|medium|deep"},
#     "sharpen": {"points": 2},
#     "pre_vol": {"verdicts": 2, "purpose_ok": true},
#     "propose": {"card": "<path>", "stamp": "principal"},
#     "jump":    {"kind": "proposal|answer|question"},
#     "gate":    {"verdict": "PASS"},
#     "relecture": {"verdict": "COHÉRENT|INCOHÉRENT|INCERTAIN", "note": "..."},  # SENS GLOBAL — livrable TEXTE
#     "learn":   {"written_back": "<ledger path>"}
#   }
# }
#
# UNIVERSELLE : pour un livrable TEXTE (artefact reponse_*.json : champ `answer`, pas de `rows`),
# le SENS GLOBAL est une RELECTURE par le même agent (qui a le contexte). Le gate EXIGE la
# présence de `relecture.verdict` ; s'il est INCOHÉRENT -> REDO. Un livrable NUMÉRIQUE
# (tableau top_*.json : `rows`) ne requiert PAS de relecture (sens_checks déterministe s'en charge).
set -euo pipefail
TRACE="${1:?usage: verify_loop.sh <loop-trace.json> [--artifact <path>]}"
shift || true
ARTIFACT=""
if [ "${1:-}" = "--artifact" ]; then ARTIFACT="$2"; shift 2 || true; fi
[ -f "$TRACE" ] || { echo "FAIL: loop-trace not found: $TRACE"; exit 2; }

python3 - "$TRACE" "$ARTIFACT" <<'PY'
import json, sys, os
trace_file, artifact = sys.argv[1], sys.argv[2]
try:
    t = json.load(open(trace_file, encoding="utf8"))
except Exception as e:
    print("FAIL: loop-trace not valid JSON:", e); sys.exit(1)

CANON = ["grasp","judge","sharpen","pre_vol","propose","jump","gate","learn"]
prob = []
steps = t.get("steps")
params = t.get("params") or {}

def has(step):
    return isinstance(params.get(step), dict)

# 1) steps array present, canonical, unique, in order
if not isinstance(steps, list) or steps != CANON:
    prob.append(f"steps must be exactly {CANON} in order — got {steps!r}")

# 2) every step has a params block (all 8 walked)
for s in CANON:
    if not has(s):
        prob.append(f"step '{s}' has no params block (not walked)")

# 3) A5 purpose-sensing: mission named + confirmed in pre_vol
mission = (t.get("mission") or "").strip()
if not mission:
    prob.append("A5: no 'mission' — purpose not sensed (name the mission/workstream it serves)")
# pre_vol purpose_ok must be true (purpose re-confirmed before jump)
pv = params.get("pre_vol") or {}
if not pv.get("purpose_ok"):
    prob.append("A5: pre_vol.purpose_ok != true (mission not re-confirmed — drift not checked)")

# 4) the gate step recorded a verdict; if the produce was a calculation it must be a gated PASS
gate = params.get("gate") or {}
if str(gate.get("verdict", "")).upper() not in ("PASS", "FAIL"):
    prob.append("gate step has no recorded verdict (PASS/FAIL)")

# 5) artifact linkage (only if the caller passed it / or the trace names one)
ta = (t.get("artifact") or "").strip()
if artifact and ta and ta != artifact and artifact not in ta:
    prob.append(f"trace artifact '{ta}' != delivered artifact '{artifact}'")
if not ta:
    prob.append("trace has no 'artifact' (which deliverable was this loop for?)")

# 6) jump kind + learn write-back present (loop closed)
jp = params.get("jump") or {}
if jp.get("kind") not in ("proposal","answer","question"):
    prob.append("jump.kind must be proposal|answer|question")
lp = params.get("learn") or {}
if not (lp.get("written_back") or "").strip():
    prob.append("learn has no written_back (loop not closed with a write-back)")

# 7) SENS GLOBAL — relecture par le même agent (TEXTE uniquement). On distingue un livrable
#    TEXTE d'un tableau numérique par la FORME de l'artefact : un reponse_*.json a un champ
#    `answer` (pas de `rows`) ; un top_*.json (tableau) a `rows`.
#    Pour un TEXTE, la relecture (sens global) est REQUISE ; INCOHÉRENT -> REDO (bloquant).
#    Pour un NUMÉRIQUE, la relecture n'est pas requise (sens_checks déterministe s'en charge).
def is_text_deliverable(path):
    if not path or not os.path.exists(path):
        return False
    try:
        d = json.load(open(path, encoding="utf8"))
    except Exception:
        return False
    if isinstance(d, dict):
        return ("answer" in d) and not isinstance(d.get("rows"), list)
    return False

if is_text_deliverable(artifact):
    relecture = params.get("relecture")
    if not isinstance(relecture, dict) or not str(relecture.get("verdict", "")).strip():
        prob.append("sens global: texte sans relecture (params.relecture.verdict requis) — relis et juge la cohérence")
    else:
        v = str(relecture.get("verdict", "")).upper()
        # EXPLICATION du pourquoi : on retransmet le `note` du relecteur (la vraie raison),
        # au lieu du template generique. L'agent sait quoi corriger.
        why = str(relecture.get("note", "")).strip()
        if v == "INCOHÉRENT":
            base = "sens global: relecture = INCOHÉRENT (la réponse contredit les données)"
            if why:
                base += f" — {why}"
            prob.append(base + " — REDO, refais (corrige la cause indiquée)")
        elif v == "INCERTAIN":
            # AMBIGU : comme INCOHÉRENT, ça REMONTE (l'agent doit clarifier avant de livrer),
            # mais en expliquant que c'est INCERTAIN (pas une erreur franche) + la note.
            base = "sens global: relecture = INCERTAIN (la réponse est ambiguë, non confirmée)"
            if why:
                base += f" — {why}"
            prob.append(base + " — REDO, précise ou lève l'ambiguïté avant de relivrer")
        elif v != "COHÉRENT":
            prob.append(f"sens global: verdict de relecture '{v}' invalide (COHÉRENT|INCOHÉRENT|INCERTAIN)")

if prob:
    for x in prob:
        print("FAIL", x)
    print("RESULT: LOOP NOT WALKED — REDO (missing/out-of-order step or no purpose citation)")
    sys.exit(1)
print("RESULT: LOOP WALKED — 8 steps in order, purpose sensed (mission cited), artifact linked.")
sys.exit(0)
PY
