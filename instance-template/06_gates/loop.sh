#!/usr/bin/env bash
# loop.sh — LE script du LOOP : le LLM doit parcourir les 8 étapes (GRASP→…→LEARN)
# et les écrire dans le looptrace. Le plugin (gdbc-gate) ensuite VALIDE via verify_loop.sh
# et, si une étape manque, STEER le LLM pour qu'il la complète.
#
# Usage : loop.sh <tour>            # initialise le looptrace des 8 étapes + affiche la consigne
# Sortie : exit 0 ; le looptrace porte steps (8) + params (à remplir par le LLM).
set -euo pipefail
R="$(cd "$(dirname "$0")/.." && pwd)"; G="$R/06_gates"
TOUR="${1:?usage: loop.sh <tour>}"
LT="$G/deliverables/${TOUR}.looptrace.json"
mkdir -p "$G/deliverables"
python3 - "$LT" <<'PY'
import json, sys
lt = sys.argv[1]
json.dump({
  "steps": ["grasp","judge","sharpen","pre_vol","propose","jump","gate","learn"],
  "params": {},
  "mission": "",
}, open(lt, "w", encoding="utf8"), ensure_ascii=False, indent=2)
PY
echo "[loop] LOOP (8 étapes) — initialisé : $LT"
echo "[loop] Ta tâche = parcourir le LOOP et remplir CHAQUE étape :"
echo "  1 grasp   (nomme la mission) · 2 judge (profondeur) · 3 sharpen (contexte)"
echo "  4 pre_vol (plan) · 5 propose (propose) · 6 jump (produis) · 7 gate (PASS) · 8 learn (write-back)"
echo "[loop] La réponse ne sort que si les 8 étapes sont remplies (verify_loop PASS)."
exit 0
