---
name: snemo-graph-extraction
description: Use when a file read (PDF, DOCX, web page, offer, deck) reveals entity relations worth recording — you extract SPO triples as JSON and deliver them to the deterministic graph store via ingest.sh. The LLM only delivers triples; the store builds the graph.
---

# Graph extraction — the LLM delivers triples, the deterministic plane builds the graph

> **Presence check FIRST:** this skill delivers triples to `state/graph/ingest.sh`. In a `ledger`-mode
> instance the graph store may be scaffold-only (no `ingest.sh`, no `nodes.json`/`edges.json`; see
> `state/graph/README.md`). If the graph store is not wired, do NOT run the ingest/verify steps —
> record the relation in the ledger as a judgment instead. Replace any example entity names with the
> instance's own.

You never edit `state/graph/nodes.json` or `edges.json` directly. Your only job is to **extract** relations from what you read and deliver them as JSON. The store validates, resolves/creates nodes, writes edges with provenance, dedupes, and flags contradictions.

**When to use:** a file read (an offer, a deck, a registry page, a website, an email) reveals a **relation between entities** that would change a future decision — e.g. who serves whom, who is a prospect, what references what. If you only found a *judgment* (no entity relation), record a belief instead and skip this skill.

**Extraction shape:** subject / predicate / object / source / date / confidence. Curated predicates (references, serves, is-a, supplies, covers, supersedes). Aim for a small, high-value set, not an exhaustive dump.

**Flow (only where the graph store is wired):**
1. Extract SPO triples as JSON.
2. Ingest: `state/graph/ingest.sh '<json>'` (or a `triples.json` file).
3. Verify: `state/graph/check_graph.sh` (sweep + integrity).

**Guardrails:** never edit `nodes.json`/`edges.json` directly · every triple carries provenance · a contradiction is flagged, not silently resolved · extraction only — the engine never computes.
