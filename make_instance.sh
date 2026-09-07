#!/bin/bash
# make_instance.sh — instantiate a standalone SNemo agent instance (own brain, own memory).
# Usage: make_instance.sh <target> <name> [preset-id]
#   <target>     absolute path of the new instance (must be empty)
#   <name>       instance name ({{INSTANCE_NAME}})
#   [preset-id]  preset id (default = the name, kebab-case)
# Copies the generic skeleton (instance-template/), parameterizes placeholders,
# copies the canonical gates from the brain's 06_gates/, then prints the
# Phase 3–6 use-case grounding checklist. Refuses to overwrite a non-empty target.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"   # .../Machinery/08_rh
TEMPLATE="$HERE/instance-template"
MACHINERY="$(cd "$HERE/.." && pwd)"                    # .../Machinery
BRAIN="$(cd "$MACHINERY/.." && pwd)"                   # .../SNemo agent copy
# GBC holds the COMPLETE generic standalone gate set (incl. verify_ledger.sh, check_graph.sh,
# html_crosscheck.py, schema_profile.py, db_schema_profile.json). The brain's 06_gates is a
# partial shared-brain variant. Copy the generic standalone set from GBC.
GBC="/Users/mouradaissou/GBC/Snemo Agent"
GATES_SRC="${GBC_GATES_SRC:-$GBC/06_gates}"

TARGET="${1:?usage: make_instance.sh <target> <name> [preset-id]}"
NAME="${2:?usage: make_instance.sh <target> <name> [preset-id]}"
PRESET="${3:-$(printf '%s' "$NAME" | tr '[:upper:] ' '[:lower:]-')}"

# --- preconditions: refuse non-empty target ---------------------------------
if [ -e "$TARGET" ] && [ -n "$(ls -A "$TARGET" 2>/dev/null)" ]; then
  echo "FAIL: target not empty: $TARGET (refusing to overwrite)"
  exit 1
fi
[ -d "$TEMPLATE" ] || { echo "FAIL: template not found: $TEMPLATE"; exit 1; }
[ -d "$GATES_SRC" ] || { echo "FAIL: gates source not found: $GATES_SRC"; exit 1; }

# --- 0. spec self-check first: refuse to build from an incoherent functional spec ----------
# The spec (AGENT_SPEC.md) is the source of truth for "what an instance is". If it drifts
# (group count mismatch, incomplete/incoherent), generation would propagate the drift to every
# instance. Fail fast so the spec is fixed at the source, not inherited by new instances.
if [ -f "$HERE/spec_check.sh" ]; then
  if bash "$HERE/spec_check.sh" >/dev/null 2>&1; then
    echo "spec_check: PASS (functional spec coherent)"
  else
    echo "FAIL: functional spec is incoherent — run 'bash $HERE/spec_check.sh' and fix before generating."
    exit 1
  fi
fi

# --- 1. copy skeleton --------------------------------------------------------
mkdir -p "$TARGET"
cp -R "$TEMPLATE"/. "$TARGET"/

# --- 2. copy canonical gates (generic) --------------------------------------
# Copy the generic standalone gate set, but EXCLUDE domain-state files (GBC's own
# db_schema_profile.json, definitions.json, journal, calc_out, demo fixtures).
cp -R "$GATES_SRC"/. "$TARGET/06_gates/" 2>/dev/null || true
rm -rf "$TARGET/06_gates/db_schema_profile.json" \
       "$TARGET/06_gates/definitions.json" \
       "$TARGET/06_gates/journal_conformite.jsonl" \
       "$TARGET/06_gates/calc_out" \
       "$TARGET/06_gates/g_calc_demo" \
       "$TARGET/06_gates/sanity_gate_demo" 2>/dev/null || true
# re-point gates at THIS instance's ledger by shipping the instance brains.sh
cp "$TEMPLATE/state/gates/brains.sh" "$TARGET/state/gates/brains.sh"

# --- 3. parameterize placeholders -------------------------------------------
# Substitute {{INSTANCE_NAME}}, {{ROOT}}, {{PRESET_ID}}, and derived doc names.
SUB() {  # SUB file
  sed -i '' \
    -e "s|{{INSTANCE_NAME}}|$NAME|g" \
    -e "s|{{ROOT}}|$TARGET|g" \
    -e "s|{{PRESET_ID}}|$PRESET|g" \
    -e "s|{{FRAMEWORK_FILE}}|FRAMEWORK_$(printf '%s' "$NAME" | tr '[:upper:] ' '[:lower:]-').md|g" \
    -e "s|{{DATA_DOCTRINE}}|API_$(printf '%s' "$NAME" | tr '[:upper:] ' '[:lower:]-').md|g" \
    -e "s|{{MODEL_GUIDE}}|API/$(printf '%s' "$NAME" | tr '[:upper:] ' '[:lower:]-')_API_MODEL.md|g" \
    -e "s|{{TOOL_FILE}}|API/$(printf '%s' "$NAME" | tr '[:upper:] ' '[:lower:]-')_api.py|g" \
    -e "s|{{DOCTRINE_FILE}}|DOCTRINE.md|g" \
    -e "s|{{MISSION}}|(mission to be committed by the user)|g" \
    -e "s|{{MISSION_INTERPRETATION}}|(to be derived once the mission is committed)|g" \
    "$1"
}
while IFS= read -r f; do SUB "$f"; done < <(grep -rl '{{' "$TARGET" 2>/dev/null || true)

# rename the `preset/{{PRESET_ID}}` folder to the real preset id (contents already substituted)
if [ -d "$TARGET/preset/{{PRESET_ID}}" ] && [ "$PRESET" != "{{PRESET_ID}}" ]; then
  mv "$TARGET/preset/{{PRESET_ID}}" "$TARGET/preset/$PRESET" 2>/dev/null || true
fi

# --- 3b. register the preset so it is SELECTABLE in the session picker ---------
# The harness discovers presets from ~/.dsh/.agent-presets/. Without this copy the
# instance's preset exists in the workspace but never shows in the picker.
APREG="$HOME/.dsh/.agent-presets/$PRESET"
if [ "$PRESET" != "{{PRESET_ID}}" ] && [ -d "$TARGET/preset/$PRESET" ]; then
  mkdir -p "$HOME/.dsh/.agent-presets"
  if [ -e "$APREG" ] && [ -n "$(ls -A "$APREG" 2>/dev/null)" ]; then
    echo "WARN: preset '$PRESET' already registered ($APREG) — leaving it as-is (not overwriting)"
  else
    cp -R "$TARGET/preset/$PRESET/." "$APREG/" 2>/dev/null || echo "WARN: preset registration copy failed"
    echo "preset registered: $APREG (selectable in the session picker)"
  fi
fi

echo "Instance scaffolded: $TARGET"
echo "Name: $NAME   preset: $PRESET"

# --- 4. verify generic gates pass + generate the boot digest ------------------
( cd "$TARGET" && bash 06_gates/verify_ledger.sh >/dev/null 2>&1 && echo "verify_ledger: PASS (brains.sh resolves)" || echo "verify_ledger: CHECK (ledger path)" )
( cd "$TARGET" && bash state/memory/make_brief.sh >/dev/null 2>&1 && echo "boot digest: generated (BRIEF.md + AGENTS.md pointer)" || echo "boot digest: CHECK make_brief.sh" )
if [ -f "$TARGET/tests/test_gate.sh" ]; then
  ( cd "$TARGET" && bash tests/test_gate.sh >/dev/null 2>&1 && echo "gate harness: PASS" || echo "gate harness: see tests/test_gate.sh" )
fi

# --- 5. print the use-case grounding checklist -------------------------------
cat <<EOF

=== USE-CASE GROUNDING (Phases 3–6, not scripted) ===
Phase 3 — Ground the use case:
  [ ] SPEC/01 mission + SPEC/04 sub-missions filled
  [ ] FRAMEWORK_*.md (method/relations/rules, NO numbers) written
  [ ] API_*.md data doctrine (or mark "advisory, no data")
  [ ] if programmatic source: <name>_api.py reader + schema_profile + model guide
Phase 4 — Seed memory:
  [ ] settled decisions → state/memory/beliefs.md B-ids
  [ ] divergences → contradictions (never silent)
  [ ] state/memory/make_brief.sh regenerated (digest stamp = ledger max)
Phase 5 — Wire:
  [ ] READ_FIRST.md lists core → SPEC → framework → data doctrine → tool (current only)
  [ ] AGENTS.md read-order includes READ_FIRST + framework
  [ ] registry row added in the shared brain (standalone instance)
Phase 6 — Validate:
  [ ] one gated deliverable end-to-end (resolve → engine → gate → deliver), reconciled
  [ ] gate it via the GENERIC driver `06_gates/g_gate_deliverable.sh` (run_calc --verify → production_gate → g_calc_delivery) — never a domain-specific bypass

Anti-miss (10): brains.sh exists · READ_FIRST current tooling · AGENTS.md read-order ·
  preset resolves for THIS instance · memory substrate complete (MODE+agenda+register) ·
  registered standalone · MODE exists · framework has the "where values live" table ·
  ledger seeded · one gated deliverable (not files present, gated via g_gate_deliverable.sh).
EOF
