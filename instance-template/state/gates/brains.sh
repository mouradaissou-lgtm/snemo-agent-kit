#!/bin/bash
# brains.sh — centralized path resolution for this instance.
# Exports the variable names the (generic, formerly GBC) gates read, pointing at THIS instance's
# own root. One source of truth so no gate hardcodes a stale path.
# Override the root with SNEMO_DIR; default = this workspace's own root.
set -euo pipefail

SNEMO_DIR="${SNEMO_DIR:-{{ROOT}}}"
GBC_CORE="$SNEMO_DIR/AGENT_CORE.md"
GBC_LEDGER="$SNEMO_DIR/state/memory/beliefs.md"
GBC_AGENDA="$SNEMO_DIR/state/agenda.md"
GBC_PROJECTS="$SNEMO_DIR/state/projects.md"
GBC_GRAPH_DIR="$SNEMO_DIR/state/graph"
GBC_GRAPH_CHECK="$GBC_GRAPH_DIR/check_graph.sh"
GBC_GATES="$SNEMO_DIR/06_gates"
# NOTE: the forget-list lives INSIDE the ledger (beliefs.md §FORGET LIST), not a separate file.

export SNEMO_DIR GBC_CORE GBC_LEDGER GBC_AGENDA GBC_PROJECTS \
  GBC_GRAPH_DIR GBC_GRAPH_CHECK GBC_GATES
