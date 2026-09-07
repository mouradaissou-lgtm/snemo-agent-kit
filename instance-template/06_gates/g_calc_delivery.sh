#!/usr/bin/env bash
# g_calc_delivery.sh <artefact> — garde de livraison (B-127) + verrou d'étapes (B-132).
# Pas de verification.json (ou non indépendant) => REFAIS avec run_calc --verify (correction).
# Le compteur d'étapes (g_livraison_verif.py) REFUSE si toutes les étapes du gate ne sont pas
# franches (dernier production_gate = PASS + les 3 dims PASS) — verrou d'exécution, pas convention (B-132).
set -e
ART="${1:?artefact requis}"
DIR="$(dirname "$ART")"; BASE="$(basename "$ART")"
# Sidecar is resolved as <artifact-stem>_verification.json first, then fall back to the literal
# "verification.json" (the name run_calc.py writes). This tolerates BOTH conventions: an artifact
# produced by run_calc carries a co-located "verification.json"; a script-produced artifact (e.g. an
# aggregator writing <artefact>_verification.json) carries a suffixed sidecar. Unconditionally
# demanding the literal name made every honest suffixed artifact REDO.
STEM="${BASE%.*}"
SIDE=""
for cand in "$DIR/$STEM"'_verification.json' "$DIR/verification.json"; do
  [ -f "$cand" ] && { SIDE="$cand"; break; }
done
JF="$(dirname "$0")/journal_conformite.jsonl"
# Timestamp en heure LOCALE (sans -u) pour être cohérent avec production_gate.py (datetime.now()).
# Avant, `date -u` (UTC) créait un décalage de 2h → B-48 voyait "delivery avant gate" → faux REDO (B-48).
now=$(date +%Y-%m-%dT%H:%M:%S)
log(){ echo "{\"ts\":\"$now\",\"livrable\":\"$BASE\",\"stage\":\"delivery\",\"verdict\":\"$1\"}" >> "$JF"; }
if [ -z "$SIDE" ]; then
  echo "DELIVERY REDO — $BASE sans verification.json (ni <stem>_verification.json) → refaire avec 'run_calc --verify' puis re-livrer."
  log "REDO"; exit 2
fi
IND=$(python3 -c "import json,sys; d=json.load(open('$SIDE')); print(d['verification'].get('independent'))" 2>/dev/null || echo "")
if [ "$IND" != "True" ]; then
  echo "DELIVERY REDO — vérification non indépendante → refaire avec une seconde voie différente du producteur."
  log "REDO"; exit 2
fi
# B-144 — indépendance RÉELLE : verify_source != source_ref (sinon vérification circulaire)
CIRC=$(python3 -c "import json,sys; d=json.load(open('$SIDE')); vs=d['verification'].get('verify_source'); sr=d.get('source_ref'); print('1' if (vs and sr and vs==sr) or not vs else '0')" 2>/dev/null || echo "1")
if [ "$CIRC" = "1" ]; then
  echo "DELIVERY REDO — indépendance circulaire (verify_source == source_ref, B-144) → vérifier depuis une AUTRE source."
  log "REDO"; exit 2
fi
# VERROU B-132 : compteur d'étapes — toutes les étapes du gate doivent être franches (dernier gate PASS + 3 dims)
if ! GATE_JOURNAL="$JF" python3 "$(dirname "$0")/g_livraison_verif.py" "$ART"; then
  echo "DELIVERY REDO — gate non satisfaite (compteur d'étapes) → refaire (B-132)."
  log "REDO"; exit 2
fi
echo "DELIVERY PASS — $BASE (verification.json indépendant + toutes étapes du gate franches)."
log "PASS"; exit 0
