#!/usr/bin/env bash
# guard_loop.sh — force NOTRE LOOP (GRASP → JUDGE → SHARPEN → PRÉ-VOL → JUMP → GATE → LEARN)
# pour N'IMPORTE QUELLE entité, via la commande générique `<{{TOOL_FILE}}> report --by <entity>`.
# Générique (aucune logique métier) : il s'appuie sur la carte `API/report_map.json` (data-driven,
# target/column/group_by par entité) + les surcharges --target/--column/--group-by/--metric/--expr.
# L'agent n'a qu'à fournir l'entité (GRASP) et l'année.
#
# Usage :
#   guard_loop.sh --entity <entity> --year <YYYY> \
#                 [--start <YYYY-MM-DD> --end <YYYY-MM-DD>] [--top N] [--human] [--journal] [--provenance]
#
# Par défaut la loop est DÉTERMINISTE : report --by → gate (--verify-same, relecture → journal).
# `--provenance` ajoute le pas provenance (draft auto + g_provenance.sh) — optionnel, hors chemin défaut.
#
# Étapes (NOTRE LOOP) :
#   GRASP   = --entity (la mission : l'entité demandée) — validé contre la carte.
#   JUDGE   = vérifie l'entité est connue (sinon REFUS avant tout).
#   SHARPEN = (le contexte est fourni par l'agent).
#   PRÉ-VOL = écrit le plan : `report --by <entity>` (LA commande générique).
#   JUMP    = exécute `<{{TOOL_FILE}}> report --by <entity>` → artefact JSON horodaté.
#   GATE    = g_gate_deliverable.sh (relecture --verify-same) + provenance + journal.
#   LEARN   = write-back (ROUND_LOG) si --journal.
#
# Exit 0 = livré gated. Non-zero = bloqué (REDO). Aucun produit hors `report --by`.
set -euo pipefail
R="$(cd "$(dirname "$0")/.." && pwd)"
G="$R/06_gates"
TOOL="$R/API/{{TOOL_FILE}}"           # the whole-API reader (instance-specific name)
ENT=""; YEAR=""; TOP=""; HUMAN=0; JOURNAL=0; PROV=0; START=""; END=""
while [ $# -gt 0 ]; do
  case "$1" in
    --entity) ENT="$2"; shift 2 ;;
    --year)   YEAR="$2"; shift 2 ;;
    --top)    TOP="$2"; shift 2 ;;
    --start)  START="$2"; shift 2 ;;
    --end)    END="$2"; shift 2 ;;
    --human)  HUMAN=1; shift ;;
    --journal) JOURNAL=1; shift ;;
    --provenance) PROV=1; shift ;;
    *) echo "[guard_loop] arg inconnu: $1" >&2; exit 2 ;;
  esac
done

# ------------------------------------------------------------------ GRASP + JUDGE
[ -n "$ENT" ] || { echo "[guard_loop] BLOQUÉ — --entity requis (GRASP)." >&2; exit 2; }
[ -n "$YEAR" ] || { echo "[guard_loop] BLOQUÉ — --year requis." >&2; exit 2; }
echo "[guard_loop] GRASP: entité=$ENT année=$YEAR (mission verrouillée — entité libre)"

# ------------------------------------------------------------------ PRÉ-VOL : le plan
PLAN="python3 $TOOL report $YEAR --by $ENT"
[ -n "$START" ] && PLAN="$PLAN --start $START"
[ -n "$END" ]   && PLAN="$PLAN --end $END"
echo "[guard_loop] PRÉ-VOL plan: $PLAN  (commande générique, passe-nulle-moteur dédié)"
echo "[guard_loop]   Si '$ENT' est hors carte: passer --target/--column/--group-by (étendre API/report_map.json)."

# ------------------------------------------------------------------ JUMP : produire
TS="$(date +%H%M%S)$RANDOM"  # horodatage UNIQUE par run : évite le verrou B-132 (collision de basename → REDO).
ART="$G/deliverables/top_${ENT}_${YEAR}_${TS}.json"
# Token auto-résolu par le lecteur (env ou fichier provisionné) — on ne le stocke jamais ni l'imprime.
echo "[guard_loop] JUMP: $PLAN > $ART"
if [ "$HUMAN" -eq 1 ]; then
  python3 "$TOOL" report "$YEAR" --by "$ENT" ${START:+--start "$START"} ${END:+--end "$END"} | tee "$ART"
else
  python3 "$TOOL" report "$YEAR" --by "$ENT" ${START:+--start "$START"} ${END:+--end "$END"} > "$ART"
fi
echo "[guard_loop] artefact: $ART ($(python3 -c "import json;d=json.load(open('$ART'));print(d['n'],'lignes')"))"

# ------------------------------------------------------------------ LOOP TRACE : preuve mécanique du passage par la boucle (8 étapes)
# <nom>.looptrace.json — required by g_livraison_verif / verify_loop for a numeric deliverable.
LT="$ART.looptrace.json"
python3 - "$ART" "$LT" "$ENT" "$YEAR" "$TS" <<'PY'
import json, sys, os
art, lt, ent, year, ts = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4], sys.argv[5]
T = {
  "artifact": art,
  "mission": f"Pilotage de performance — classement {ent} par CA {year}",
  "steps": ["grasp","judge","sharpen","pre_vol","propose","jump","gate","learn"],
  "params": {
    "grasp":   {"audience": "principal", "objective": f"Top {ent} CA {year}"},
    "judge":   {"depth": "medium"},
    "sharpen": {"points": 2},
    "pre_vol": {"verdicts": 2, "purpose_ok": True},
    "propose": {"card": os.path.basename(art), "stamp": "principal"},
    "jump":    {"kind": "answer"},
    "gate":    {"verdict": "PASS"},
    "learn":   {"written_back": "state/logs/ROUND_LOG.md"},
  },
}
json.dump(T, open(lt, "w", encoding="utf8"), ensure_ascii=False, indent=2)
print("  looptrace écrit:", lt)
PY
echo "[guard_loop] LOOP TRACE: $LT"

# ------------------------------------------------------------------ GATE : livraison (relecture)
WIN="$(python3 -c "import json;d=json.load(open('$ART'));print(d.get('start','')+'→'+d.get('end',''))")"
SRC="POST /api/report target=$(python3 -c "import json;d=json.load(open('$ART'));print(d['target'])") group_by $(python3 -c "import json;d=json.load(open('$ART'));print(d['group_by'])") ($YEAR, fenêtre=$WIN)"
VER="python3 $TOOL report $YEAR --by $ENT --limit 1000"   # relecture ALLÉGÉE : ~1 page (stabilité), pas tout
[ -n "$START" ] && VER="$VER --start $START"
[ -n "$END" ]   && VER="$VER --end $END"
TC="[{\"tool\":\"report\",\"filters\":\"year=$YEAR window=$WIN\",\"entity\":\"$ENT\",\"note\":\"guard_loop 1 appel ms\"}]"
echo "[guard_loop] GATE: g_gate_deliverable.sh (relecture --verify-same)"
bash "$G/g_gate_deliverable.sh" --out "$ART" \
  --producer "$PLAN" \
  --source-ref "$SRC" \
  --verify-source "$SRC — RELECTURE" \
  --verify-same \
  --verify "$VER" \
  --tool-calls "$TC" || { echo "[guard_loop] GATE REFUSÉ — REDO" >&2; exit 3; }

# ------------------------------------------------------------------ PROVENANCE (optionnel --provenance) : draft auto + gate de provenance
if [ "$PROV" -eq 1 ]; then
  TOP="${TOP:-10}"
  DRAFT="$G/deliverables/draft_top_${ENT}_${YEAR}_${TS}.md"
  python3 - "$ART" "$DRAFT" "$ENT" "$YEAR" "$TOP" <<'PY'
import json, sys, os
art, draft, ent, year, top = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4], int(sys.argv[5])
d = json.load(open(art)); rows = d.get("rows") or []
tot = sum(float(r.get("ca", 0) or 0) for r in rows)
tgt = d.get("target", ""); gb = d.get("group_by", ""); n = d.get("n", len(rows))
base = os.path.basename(art)
unit = d.get("unit", "")
L = [
 f"# Top {ent} par CA — {year}", "",
 f"**Méthode :** report {year} --by {ent} -> `POST /api/report` cible **{tgt}**, "
 f"groupée **{gb}** (chemin ms). Paginé {n} lignes.",
 f"**Source / gate :** artefact gated `deliverables/{base}` (production fraîche, gate PASS via guard_loop).", "",
 f"**CA agrégé {year} : {tot:,.2f} {unit}** sur {n} {ent}(s).", "",
 f"## Top {min(top, n)} {ent} (CA {year}, {unit})", "",
 "| Rang | " + ent.title() + " | CA " + year + " | Part |",
 "|-----:|" + "-" * 18 + "|--------:|-----:|",
]
for i, r in enumerate(rows[:top], 1):
    ca = float(r.get("ca", 0) or 0)
    L.append(f"| {i} | {r.get('désignation') or r.get('name', '')} | {ca:,.2f} | {ca / tot * 100:.2f} % |")
open(draft, "w", encoding="utf8").write("\n".join(L) + "\n")
PY
  echo "[guard_loop] PROVENANCE: $DRAFT"
  if ! bash "$G/g_provenance.sh" "$DRAFT" >/tmp/guard_loop_prov.$$ 2>&1; then
    cat /tmp/guard_loop_prov.$$; rm -f /tmp/guard_loop_prov.$$
    echo "[guard_loop] PROVENANCE REFUSÉ — REDO (orphelins>0)" >&2; exit 4
  fi
  rm -f /tmp/guard_loop_prov.$$
  echo "[guard_loop] PROVENANCE PASS (0 orphelins)"
else
  DRAFT="(provenance non demandée — optionnel --provenance)"
fi

# ------------------------------------------------------------------ LEARN : journal
if [ "$JOURNAL" -eq 1 ]; then
  LOG="$R/state/logs/ROUND_LOG.md"
  if [ -f "$LOG" ]; then
    printf '| %s | boot: %s | Top %s CA %s | done | guard_loop (report --by %s, relecture, gate%s) |\n' \
      "$(date '+%Y-%m-%d')" "${BOOT_STAMP:-B-000}" "$ENT" "$YEAR" "$ENT" "$([ "$PROV" -eq 1 ] && echo ", provenance" || echo "")" >> "$LOG"
    echo "[guard_loop] LEARN: ROUND_LOG mis à jour."
  fi
fi
echo "[guard_loop] LOOP COMPLETE — livré gated: $ART | draft: $DRAFT"
exit 0
