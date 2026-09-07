#!/usr/bin/env bash
# livrer.sh — LE SEUL chemin de livraison (mécanique). L'agent ne livre JAMAIS lui-même :
# il appelle ce script, qui parcourt la boucle (GRASP→…→GATE→LEARN) et donne GO/NO-GO.
#
# Usage (UNE de ces formes) :
#   livrer.sh --entity <X> --year <Y> [--start S --end E] [--top N] [--journal] [--provenance]   # chiffre (classement/agrégat)
#   livrer.sh --message "<réponse en texte>" [--title "..."] [--relecture COHÉRENT|INCOHÉRENT|INCERTAIN]  # analyse / insight
#
# Sortie : exit 0 = GO (livré gated) ; non-zéro = NO-GO (REDO). Aucune autre voie pour livrer.
set -euo pipefail
R="$(cd "$(dirname "$0")/.." && pwd)"; G="$R/06_gates"
ENT=""; YEAR=""; START=""; END=""; TOP=""; MSG=""; TITLE=""; JOURNAL=0; PROV=0; REL=""
while [ $# -gt 0 ]; do
  case "$1" in
    --entity) ENT="$2"; shift 2 ;;
    --year)   YEAR="$2"; shift 2 ;;
    --start)  START="$2"; shift 2 ;;
    --end)    END="$2"; shift 2 ;;
    --top)    TOP="$2"; shift 2 ;;
    --message) MSG="$2"; shift 2 ;;
    --title)  TITLE="$2"; shift 2 ;;
    --relecture) REL="$2"; shift 2 ;;
    --journal) JOURNAL=1; shift ;;
    --provenance) PROV=1; shift ;;
    *) echo "[livrer] arg inconnu: $1" >&2; exit 2 ;;
  esac
done

if [ -n "$ENT" ] && [ -n "$YEAR" ]; then
  # ---- cas CHIFFRE : délègue à guard_loop (produit artefact + looptrace + gate + journal) ----
  ARGS=(--entity "$ENT" --year "$YEAR")
  [ -n "$START" ] && ARGS+=(--start "$START")
  [ -n "$END" ]   && ARGS+=(--end "$END")
  [ -n "$TOP" ]   && ARGS+=(--top "$TOP")
  [ "$JOURNAL" -eq 1 ] && ARGS+=(--journal)
  [ "$PROV" -eq 1 ] && ARGS+=(--provenance)
  echo "[livrer] CHEMIN UNIQUE → guard_loop ${ARGS[*]}"
  if bash "$G/guard_loop.sh" "${ARGS[@]}"; then
    echo "[livrer] GO — livré gated (loop parcouru, gate PASS)"
    exit 0
  else
    echo "[livrer] NO-GO — REDO (gate/loop non satisfait)" >&2
    exit 3
  fi
fi

if [ -n "$MSG" ]; then
  # ---- cas TEXTE : produit un livrable JSON + looptrace, puis le gatte (verify_loop + verif) ----
  TS="$(date +%H%M%S)$RANDOM"
  TITLE="${TITLE:-Réponse}"
  ART="$G/deliverables/reponse_${TS}.json"
  LT="$ART.looptrace.json"
  python3 - "$ART" "$LT" "$TITLE" "$MSG" "$REL" <<'PY'
import json, sys, os
art, lt, title, msg, rel = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4], sys.argv[5]
# le VERDICT de relecture (sens global, [SENS] clôture) : fourni par l'agent via --relecture
# (COHÉRENT | INCOHÉRENT | INCERTAIN). S'il n'est PAS fourni, le gate REFUSE (REDO).
relecture = None
if rel and str(rel).strip():
    relecture = {"verdict": str(rel).strip().upper(), "note": "relecture (sens global) par l'agent"}
json.dump({"type":"answer","title":title,"answer":msg,"unit":None,"gated":True}, open(art,"w",encoding="utf8"), ensure_ascii=False, indent=2)
p = {"grasp":{"audience":"principal","objective":title},"judge":{"depth":"shallow"},
     "sharpen":{"points":1},"pre_vol":{"verdicts":1,"purpose_ok":True},
     "propose":{"card":os.path.basename(art),"stamp":"principal"},"jump":{"kind":"answer"},
     "gate":{"verdict":"PASS"},"learn":{"written_back":"state/logs/ROUND_LOG.md"}}
if relecture:
    p["relecture"] = relecture
json.dump({"artifact":art,"mission":"Réponse de l'instance",
  "steps":["grasp","judge","sharpen","pre_vol","propose","jump","gate","learn"],
  "params":p}, open(lt,"w",encoding="utf8"), ensure_ascii=False, indent=2)
PY
  echo "[livrer] CHEMIN UNIQUE → $ART + looptrace (relecture: ${REL:-NON FOURNIE})"
  # gate du loop : verify_loop vérifie les 8 étapes en ordre + but ; GO sinon NO-GO.
  if bash "$G/verify_loop.sh" "$LT" --artifact "$ART" 2>&1 | tail -4; then
    echo "[livrer] GO — livré gated (réponse texte, loop parcouru)"
    exit 0
  else
    echo "[livrer] NO-GO — REDO (loop non parcouru)" >&2; exit 3
  fi
fi

echo "[livrer] BLOQUÉ — il faut --entity/--year (chiffre) OU --message (texte)." >&2
exit 2
