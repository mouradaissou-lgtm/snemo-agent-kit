#!/bin/bash
# resolve_machinery.sh — resolve the MACHINERY root for the GBC instance.
# Brain-centric: machinery lives in the brain as a Machinery/ subdir. Falls back
# to the register sibling convention only if the subdir is absent.
set -euo pipefail
CORE="$(cd "$(dirname "$0")/.." && pwd)"
if [ -d "$CORE/Machinery" ]; then
  echo "$CORE/Machinery"
else
  REG="$CORE/state/architecture.md"
  name="$(sed -n 's/^machinery: \(.*\) (.*/\1/p' "$REG" 2>/dev/null | head -1 | sed 's/[[:space:]]*$//')"
  [ -n "$name" ] || { echo "FAIL: no machinery data line — add one, never hardcode"; exit 1; }
  echo "$(dirname "$CORE")/$name"
fi
