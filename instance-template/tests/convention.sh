#!/usr/bin/env bash
# convention_generic.sh — test de convention (générique) (batterie mécanique e2e).
# Agit comme un utilisateur de l'instance : injecte chaque cas dans une session live de l'agent,
# attend le turn/end de CE tour, puis évalue les conventions C1–C8 sur le graphe d'appels
# observé + le looptrace produit + les snapshots golden. Aucun domaine : les cas sont
# synthétiques (voir convention_cases.json) ; C7 n'est jugé que si un golden est renseigné.
#
# Usage:
#   bash convention_generic.sh --session <SID> [-v] [--cases tests/convention_cases.json]
#   SID défaut = CONV_SESSION (sinon non fourni -> échec propre).
# Exit 0 = toutes conventions OK ; non-zéro = au moins un FAIL.
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CASES="$ROOT/tests/convention_cases.json"
SID="${CONV_SESSION:-}"     # 2031 par défaut
BASE="http://127.0.0.1:3080"
VERBOSE=0

while [ $# -gt 0 ]; do
  case "$1" in
    --session) SID="$2"; shift 2 ;;
    --cases)   CASES="$2"; shift 2 ;;
    -v|--verbose) VERBOSE=1; shift ;;
    *) echo "arg inconnu: $1" >&2; exit 2 ;;
  esac
done

# Session dir derived from this instance's root (never a hardcoded path): the harness
# compacts the absolute ROOT into the same "--<path>" slug the harness uses for session dirs.
SESSION_SLUG="$(python3 -c "import os,sys; p=os.path.abspath('$ROOT'); print('--' + p.lstrip('/').replace('/','-') + '--')")"
SESSION_DIR="${CONV_SESSION_DIR:-$HOME/.dsh/sessions/$SESSION_SLUG/$SID}"
TRANSCRIPT="$SESSION_DIR/session.jsonl.zstd"
OBS="$ROOT/tests/convention_observe.py"
[ -f "$TRANSCRIPT" ] || { echo "ERR: transcript introuvable $TRANSCRIPT" >&2; exit 2; }
[ -f "$OBS" ] || { echo "ERR: helper absent $OBS" >&2; exit 2; }

PASS=0; FAIL=0
FAILED_CASES=()
uuid(){ python3 -c "import uuid;print(uuid.uuid4())"; }
ok(){ echo "  OK   $1"; PASS=$((PASS+1)); }
ko(){ echo "  FAIL $1"; FAIL=$((FAIL+1)); FAILED_CASES+=("$2 :: $1"); }

wait_turn_end(){
  local start_ms="$1" deadline="$2"
  while :; do
    local res
    res=$(zstd -d -c "$TRANSCRIPT" 2>/dev/null | python3 "$OBS" wait_end "$start_ms")
    [ "${res:-0}" -gt 0 ] && { echo "$res"; return 0; }
    [ "$(date +%s)" -gt "$deadline" ] && { echo "0"; return 1; }
    sleep 8
  done
}

observe_case(){
  zstd -d -c "$TRANSCRIPT" 2>/dev/null | python3 "$OBS" observe "$1" "$2" "$VERBOSE"
}

latest_looptrace(){
  local mode="$1" min_ms="$2"
  python3 - "$ROOT/06_gates/deliverables" "$mode" "$min_ms" <<'PY'
import os, sys
d, mode, min_ms = sys.argv[1], sys.argv[2], float(sys.argv[3])
best = None; best_m = -1
for f in os.listdir(d):
    if not f.endswith(".looptrace.json"): continue
    is_reponse = f.startswith("reponse_")
    if mode == "reponse" and not is_reponse: continue
    if mode == "entity" and is_reponse: continue
    p = os.path.join(d, f)
    m = os.path.getmtime(p) * 1000.0   # seconds -> ms, compare à min_ms (ms)
    if m >= min_ms and m > best_m:
        best = p; best_m = m
print(best or "")
PY
}

assert_case(){
  # $2 = chemin vers un fichier JSON d'observation (évite d'interpoler des guillemets dans -c)
  local id="$1" obsfile="$2" kind="$3" lt="$4" gtot="$5" gtop="$6"
  local askn last_kind has_livrer
  askn=$(python3 -c "import json;d=json.load(open('$obsfile'));print(sum(1 for c in d['calls'] if c['kind']=='ask'))")
  [ "$askn" = "0" ] && ok "C6 aucune divergence (0 ask)" || ko "C6 divergence ($askn ask_user_question)" "$id"

  last_kind=$(python3 -c "import json;d=json.load(open('$obsfile'));cs=[c for c in d['calls'] if c['kind'] in ('livrer','report','loop')];print(cs[-1]['kind'] if cs else 'none')")
  has_livrer=$(python3 -c "import json;d=json.load(open('$obsfile'));print(1 if any(c['kind']=='livrer' for c in d['calls']) else 0)")
  if [ "$has_livrer" = "1" ] && [ "$last_kind" != "report" ]; then
    ok "C1 loop obligatoire (dernier=$last_kind, livrer présent)"
  else
    ko "C1 livraison non via livrer (dernier=$last_kind livrer=$has_livrer)" "$id"
  fi

  if [ "$kind" = "numeric" ]; then
    if [ -n "$lt" ] && [ -f "$lt" ]; then
      ok_steps=$(python3 -c "import json;d=json.load(open('$lt'));w=['grasp','judge','sharpen','pre_vol','propose','jump','gate','learn'];print(1 if [s for s in d.get('steps',[]) if isinstance(s,str)]==w else 0)")
      [ "$ok_steps" = "1" ] && ok "C2 looptrace 8 steps ordonnés" || ko "C2 steps!=8/ordre" "$id"
      gp=$(python3 -c "import json;print((json.load(open('$lt')).get('params') or {}).get('gate',{}).get('verdict'))")
      [ "$gp" = "PASS" ] && ok "C3 gate PASS" || ko "C3 gate=$gp" "$id"
      purok=$(python3 -c "import json;print((json.load(open('$lt')).get('params') or {}).get('pre_vol',{}).get('purpose_ok'))")
      grasp=$(python3 -c "import json;print(bool((json.load(open('$lt')).get('params') or {}).get('grasp',{}).get('objective')))")
      [ "$purok" = "True" ] && [ "$grasp" = "True" ] && ok "C4 pertinence A5" || ko "C4 A5 purpose_ok=$purok grasp=$grasp" "$id"
      wr=$(python3 -c "import json;print((json.load(open('$lt')).get('params') or {}).get('learn',{}).get('written_back'))")
      echo "$wr" | grep -q "ROUND_LOG" && ok "C5 learn write-back" || ko "C5 learn=$wr" "$id"
      if [ -n "$gtot" ]; then
        art=$(python3 -c "import json;print(json.load(open('$lt')).get('artifact'))")
        art_total=$(python3 -c "import json,sys;a=json.load(open('$art'));rows=a.get('rows') or [];print('%.2f'%sum(float(r.get('ca',0) or 0) for r in rows if r.get('ca') is not None))" 2>/dev/null)
        dlt=$(python3 -c "import sys;print(abs(float('$art_total')-float('$gtot')))" 2>/dev/null || echo 99999)
        [ "$(python3 -c "print(1 if $dlt < 0.01 else 0)")" = "1" ] && ok "C7 précision total=$art_total (Δ=$dlt)" || ko "C7 total=$art_total vs $gtot (Δ=$dlt)" "$id"
        if [ -n "$gtop" ]; then
          art_top=$(python3 -c "import json;a=json.load(open('$art'));rows=a.get('rows') or [];print(rows[0].get('désignation') if rows else '-')")
          [ "$art_top" = "$gtop" ] && ok "C7 top1=$art_top" || ko "C7 top1=$art_top vs $gtop" "$id"
        fi
      fi
    else
      ko "C2 looptrace introuvable" "$id"
    fi
  else
    if [ -n "$lt" ] && [ -f "$lt" ]; then
      art=$(python3 -c "import json;print(json.load(open('$lt')).get('artifact'))")
      bash "$ROOT/06_gates/verify_loop.sh" "$lt" --artifact "$art" >/dev/null 2>&1 \
        && ok "C8 verify_loop vert (texte)" || ko "C8 verify_loop FAIL (texte)" "$id"
    else
      ko "texte sans looptrace" "$id"
    fi
  fi
}

echo "=== Convention — batterie sur session $SID (instance: $ROOT) ==="
N=$(python3 -c "import json;print(len(json.load(open('$CASES'))['cases']))")

for idx in $(seq 0 $((N-1))); do
  prompt=$(python3 -c "import json;print(json.load(open('$CASES'))['cases'][$idx]['prompt'])")
  kind=$(python3 -c "import json;print(json.load(open('$CASES'))['cases'][$idx]['kind'])")
  gtot=$(python3 -c "import json;print(json.load(open('$CASES'))['cases'][$idx].get('expect',{}).get('golden_total') or '')")
  gtop=$(python3 -c "import json;print(json.load(open('$CASES'))['cases'][$idx].get('expect',{}).get('golden_top1') or '')")
  id=$(python3 -c "import json;print(json.load(open('$CASES'))['cases'][$idx]['id'])")

  echo ""
  echo "───── CAS $((idx+1))/$N : $id ($kind) ─────"
  echo "  prompt: ${prompt:0:90}"

  start_ms=$(python3 -c "import time;print(int(time.time()*1000))")
  rpc=$(uuid)
  resp=$(curl -s -m 12 -X POST "$BASE/api/session.prompt" -H "Content-Type: application/json" \
    -d "{\"type\":\"client-request\",\"rpcId\":\"$rpc\",\"method\":\"session.prompt\",\"payload\":{\"sessionId\":\"$SID\",\"mode\":\"queue\",\"content\":[{\"type\":\"text\",\"text\":$(python3 -c "import json,sys;print(json.dumps(sys.argv[1]))" "$prompt")}]}}")
  echo "$resp" | grep -q '"accepted":true' || { ko "injection échouée" "$id"; continue; }

  end_ms=$(wait_turn_end "$start_ms" "$(( $(date +%s) + 320 ))")
  if [ "$end_ms" = "0" ]; then ko "timeout turn/end 320s" "$id"; continue; fi
  obs=$(observe_case "$start_ms" "$end_ms")
  obsfile="/tmp/conv_obs_${id}_$$.json"
  printf '%s' "$obs" > "$obsfile"

  if [ "$kind" = "numeric" ]; then lt=$(latest_looptrace "entity" "$start_ms"); else lt=$(latest_looptrace "reponse" "$start_ms"); fi

  assert_case "$id" "$obsfile" "$kind" "$lt" "$gtot" "$gtop"
done

echo ""
echo "════════════ RÉSUMÉ ════════════"
echo "PASS=$PASS  FAIL=$FAIL"
if [ "${#FAILED_CASES[@]}" -gt 0 ]; then
  echo "ÉCHECS:"
  for f in "${FAILED_CASES[@]}"; do echo "  - $f"; done
fi
[ "$FAIL" -eq 0 ]
