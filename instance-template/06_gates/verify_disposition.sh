#!/bin/bash
# G4 — Disposition gate (PROVISIONAL)
# Every deliverable under 07_reports/ must cite a DECISION_LOG disposition row
# that actually exists. DECISION_LOG = journal durable des décisions (seul fichier à
# décisions réelles). DECISION_QUEUE = file d'attente vide, ignorée.
# Exit 0 = pass, 1 = fail.
set -euo pipefail
# Canonical home: brain 06_gates/ (ARC-020). Deliverables + DECISION_LOG live in
# the machinery workspace — resolved BY REFERENCE via state/resolve_machinery.sh.
CORE="$(cd "$(dirname "$0")/.." && pwd)"
MACH="$(bash "$CORE/state/resolve_machinery.sh")" || exit 1
cd "$MACH"

fail=0
found=0
for f in 07_reports/*.md; do
  [ -f "$f" ] || continue
  found=1
  # UNIQUE convention : exiger un id de décision explicite `DECISION_LOG#NNN`.
  # Un simple nom de fichier (DECISION_QUEUE.md) sans id n'est PAS une disposition.
  # Évite de prendre un '202' (date/mission) pour une réf.
  refs=$(grep -oE 'DECISION_LOG#?[0-9]{3}' "$f" | sed -E 's/DECISION_LOG#?//' | sort -u || true)
  if [ -z "$refs" ]; then
    echo "FAIL $f: no DECISION_LOG disposition reference (exige un id explicite, ex. DECISION_LOG#002)"
    fail=1
    continue
  fi
  for r in $refs; do
    row=$(printf '%03d' "$((10#$r))" 2>/dev/null || echo "$r")
    if grep -qE "^\| $row " 03_logs/DECISION_LOG.md; then
      echo "OK   $f → DECISION_LOG row $row exists"
    else
      echo "FAIL $f: cites DECISION_LOG row $row which does not exist"
      fail=1
    fi
  done
done
[ "$found" -eq 0 ] && echo "WARN: no deliverables in 07_reports/ to check"
[ "$fail" -eq 0 ] && echo "RESULT: all deliverables carry valid disposition refs"
exit $fail
