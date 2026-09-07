# Instance Pattern — how to instantiate a standalone SNemo agent (any use case)

> Reusable procedure to create a **standalone agent instance** (own brain, own memory, own gates).
> The universal core is copied by `make_instance.sh`; the only per-instance work is the use case
> (mission + framework + data source). Full functional anatomy: see `AGENT_SPEC.md`.

## The split
- **Universal core** (identical every time): identity (AGENT_CORE + SPEC), memory substrate, gates,
  task-goal system, machinery process, wiring, tests, preset skills.
- **Use-case layer** (per instance): mission, domain framework, data doctrine, reader tool + model guide
  (only if the source is programmatic), ledger seed, registry row.

## The 6 phases

**Phase 0 — Charter.** Name, use case, target path, preset id, data-source type.
*Done:* target empty, no registry collision.

**Phase 1 — Scaffold.** `make_instance.sh <target> <name> [preset]` copies the skeleton + canonical gates,
parameterizes, refuses non-empty. *Done:* all groups present; `test_gate.sh` 7/7; `verify_ledger.sh` clean.

**Phase 2 — Parameterize.** Confirm `state/gates/brains.sh` → instance root; AGENT_CORE name; architecture
register; preset stub. *Done:* gates resolve via brains.sh (no crash); boot stamp answers.

**Phase 3 — Ground the use case.** Fill SPEC/01+04 (mission, sub-missions); write `FRAMEWORK_*.md`
(method only, no numbers, ending with the "where each value lives" table); write `API_*.md` data doctrine;
build the reader tool + model guide if programmatic. *Done:* framework cites sources; if tooled — counts
work, duplicates audited, one full fetch reconciles.

**Phase 4 — Seed memory.** Settled decisions as B-ids; divergences as contradictions; regenerate the digest.
*Done:* digest stamp = ledger max.

**Phase 5 — Wire.** `READ_FIRST.md` lists core → SPEC → framework → data doctrine → tool (current only);
`AGENTS.md` read-order includes READ_FIRST + framework; add the registry row. *Done:* a simulated boot
surfaces the framework + tool by name.

**Phase 6 — Validate.** One gated deliverable end-to-end (resolve → engine → gate → deliver), reconciled;
for advisory instances, a gated evidence-cited deliverable of its kind. *Done:* gated PASS logged.
Gate any calculation through the **generic `06_gates/g_gate_deliverable.sh`** (`run_calc --verify` →
`production_gate` → `g_calc_delivery`) — never a domain-specific bypass.

## The 11 anti-miss points (what broke instances before)
1. `state/gates/brains.sh` exists **before** any gate runs.
2. `READ_FIRST.md` points only at **current** tooling (never a legacy engine).
3. `AGENTS.md` read-order includes READ_FIRST + the framework.
4. The preset cited in AGENT_CORE resolves for **this** instance.
5. Memory substrate complete: MODE + agenda + architecture register, not just beliefs.
6. Instance registered as standalone.
7. `state/memory/MODE` exists (`ledger` default).
8. Framework carries the "where each value lives" table (or the no-data equivalent).
9. Ledger seeded with settled decisions before the first business question.
10. Validation = one gated deliverable end-to-end, not files present — gate it via the GENERIC
    `06_gates/g_gate_deliverable.sh` (`run_calc --verify` → `production_gate` → `g_calc_delivery`),
    never a domain-specific bypass.
11. **The GATE doctrine is carried LOCALLY** — a standalone instance's ledger ships the generic
    gate doctrine rows (calc gate, calc container + delivery, sens mécanique, delivery lock, schema
    mapping, provenance, calc-engine + independence, fresh-production + auto-check) as its OWN B-ids
    with the core-id provenance ("instanciation locale du cœur B-1xx"), so AGENT_CORE never references
    a doctrine id that lives in a forbidden core brain (the dangling-doctrine gap).
12. **Run `core_check.sh` after any change** — the universal health check answers "is this instance
    working?" in one command (identity, memory, gates, structure, data, behavior, self). It must be
    HEALTHY before you consider an instance done.

## Data-source decision tree (Phase 3)
- **Programmatic API** → reader tool (`get/list/count/entities/resolve/audit-ids`) + schema_profile + model guide.
- **Files / documents** → read doctrine only.
- **DB (via gateway)** → gateway-only doctrine.
- **No data (advisory)** → skip data tooling entirely; Phase 6 validates an evidence-cited deliverable.

## Files
- `AGENT_SPEC.md` — the full ~70-functionality spec + how the agent works (SOURCE OF TRUTH).
- `spec_check.sh` — the spec TEST: verifies group counts, entry uniqueness, Purpose+contract,
  and referenced files exist. Run it to keep the spec coherent as it grows.
- `spec_gen.sh` — the spec GENERATE/UPDATER: `generate` → machine index (`spec_index.json`),
  `drift` → report entries below the full Purpose/Mechanism/I-O/Composes contract, `sync` → wire
  the spec contract into `test_instance.sh`.
- `instance-template/` — the generic skeleton (placeholders).
- `make_instance.sh` — the generator (self-checks `spec_check.sh` before scaffolding).
- `test_instance.sh` — the generator regression test (now also asserts the spec contract).
- This file — the procedure.
