#!/usr/bin/env bash
# update_spec_tracker.sh — PONT entre les tests de l'instance et le Spec Tracker (G8).
#
# Promeut des fonctionnalités du catalogue (`tests/spec_catalog.json`) en "covered" AVEC une preuve,
# puis régénère la couverture (`tests/spec_coverage.json`) à partir du catalogue — la couverture est
# toujours DÉRIVÉE, donc catalogue et couverture ne peuvent pas diverger.
#
# Générique : aucun domaine. Les promotions sont fournies explicitement (elles viennent des tests
# de l'instance, en Phase 3-6), jamais codées ici.
#
# Usage :
#   bash update_spec_tracker.sh --set C22=covered#gate détecte le tamper   [--set ...]
#   bash update_spec_tracker.sh --from tests/spec_updates.json            # {"C22": {"status":"covered","proof":"..."}}
#   bash update_spec_tracker.sh --show                                    # affiche le résumé
#
# Exit 0 = catalogue appliqué (+ couverture régénérée) ; 2 = entrée invalide.
set -euo pipefail
R="$(cd "$(dirname "$0")/.." && pwd)"
CAT="$R/tests/spec_catalog.json"
COV="$R/tests/spec_coverage.json"
GEN="${SPEC_GEN:-$R/../../SNemo agent copy/Machinery/08_rh/Instance/generator/spec_gen.sh}"

[ -f "$CAT" ] || { echo "catalog introuvable: $CAT" >&2; exit 2; }

SETS=(); FROM=""; SHOW=0
while [ $# -gt 0 ]; do
  case "$1" in
    --set)  SETS+=("$2"); shift 2 ;;
    --from) FROM="$2"; shift 2 ;;
    --show) SHOW=1; shift ;;
    *) echo "arg inconnu: $1" >&2; exit 2 ;;
  esac
done

if [ "$SHOW" = 1 ]; then
  python3 - "$CAT" <<'PY'
import json, sys, collections
d = json.load(open(sys.argv[1], encoding='utf8'))
c = collections.Counter(f.get('status', 'todo') for f in d.get('functions', []))
print(f"catalogue: {len(d.get('functions', []))} fonctions | {dict(c)}")
PY
  exit 0
fi

python3 - "$CAT" "$FROM" "${SETS[@]:-}" <<'PY'
import json, sys
cat_path, from_path = sys.argv[1], sys.argv[2]
sets = [s for s in sys.argv[3:] if s]
d = json.load(open(cat_path, encoding='utf8'))
by_id = {f['id']: f for f in d.get('functions', [])}
VALID = {'todo', 'covered', 'partial', 'absent', 'na'}

updates = {}
if from_path:
    try:
        raw = json.load(open(from_path, encoding='utf8'))
        for k, v in raw.items():
            updates[k] = (v.get('status', 'covered'), v.get('proof', ''))
    except Exception as e:
        print(f"FAIL: --from illisible ({e})", file=sys.stderr); sys.exit(2)
for s in sets:
    if '=' not in s:
        print(f"FAIL: --set attend <id>=<status>[#proof] (reçu {s!r})", file=sys.stderr); sys.exit(2)
    lhs, rhs = s.split('=', 1)
    status, _, proof = rhs.partition('#')
    updates[lhs.strip()] = (status.strip(), proof.strip())

applied, unknown = [], []
for eid, (status, proof) in sorted(updates.items()):
    if eid not in by_id:
        unknown.append(eid); continue
    if status not in VALID:
        print(f"FAIL: statut invalide {status!r} pour {eid} (attendu {sorted(VALID)})", file=sys.stderr)
        sys.exit(2)
    by_id[eid]['status'] = status
    if proof:
        by_id[eid]['proof'] = proof
    applied.append(eid)

if unknown:
    print(f"FAIL: ids inconnus du catalogue: {unknown}", file=sys.stderr); sys.exit(2)

json.dump(d, open(cat_path, 'w', encoding='utf8'), ensure_ascii=False, indent=2)
print(f"catalogue mis à jour: {len(applied)} promotion(s) {applied if applied else ''}")
PY

# la couverture est DÉRIVÉE du catalogue (jamais saisie à la main)
if [ -x "$GEN" ] || [ -f "$GEN" ]; then
  bash "$GEN" coverage --catalog "$CAT" --emit "$COV"
else
  # repli local (même sémantique que spec_gen.sh coverage) si le générateur n'est pas joignable
  python3 - "$CAT" "$COV" <<'PY'
import json, sys
MAP = {'covered': 'conform', 'partial': 'partiel', 'todo': 'todo',
       'absent': 'absent', 'manquant': 'absent', 'na': 'na'}
d = json.load(open(sys.argv[1], encoding='utf8'))
c = {'conform': 0, 'partiel': 0, 'todo': 0, 'absent': 0, 'na': 0}
for f in d.get('functions', []):
    c[MAP.get(str(f.get('status', 'todo')).lower(), 'todo')] += 1
c['total'] = len(d.get('functions', []))
json.dump({'conform': c['conform'], 'total': c['total'], 'partiel': c['partiel'],
           'todo': c['todo'], 'absent': c['absent'], 'na': c['na']},
          open(sys.argv[2], 'w', encoding='utf8'), ensure_ascii=False, indent=2)
print(f"coverage (repli) écrite: {sys.argv[2]} | {c}")
PY
fi
