# Architecture Proposal — the Agent Architecture

> **Status: PROPOSED — awaiting CEO disposition.** Mission cited: "Build the agent architecture" (goal rev 6, active). This is the blueprint; nothing is built beyond the foundation without a commit.

## Part 1 — Blueprint (7 layers)

| Layer | Folder (proposed) | What it holds | Status |
|---|---|---|---|
| L0 Purpose | `00_purpose/` | Mission, purpose chain, standing rules | ✅ committed |
| L1 Framework | `02_framework/` | Operating rules, this blueprint, versions | ✅ v1.0 |
| L2 Audit | `03_logs/` | DECISION_LOG, ROUND_LOG | ✅ skeleton |
| L3 Inbox | `01_inbox/` | Raw drops awaiting triage | ✅ empty |
| L4 Memory | `04_memory/` | Judgments & relations only — never ground-truth quantities | ⏳ to build |
| L5 Context | `05_context/` | Per-task context packs: sources, evidence refs, state | ⏳ to build |
| L6 Gates | `06_gates/` | Deterministic verification: claim→evidence checks, number recomputation, structure validation | ⏳ to build |

## Part 2 — Build phases

- **P0 — Foundation** ✅: purpose, framework, logs, inbox (done this session).
- **P1 — Memory & Context**: design + implement L4/L5 — schemas for beliefs (confidence, maturity, scope) and context packs.
- **P2 — Verification gates**: implement L6 as runnable checks inside the sandbox (a gate that verifies every new artifact's claims against its cited evidence).
- **P3 — First end-to-end capability**: a real task run through the full loop (ORIENT→…→LEARN) with the gates active, producing a verified artifact.

## Part 3 — How we'll know it's built (verification criteria)

1. P1 done: memory + context schemas exist, are versioned, and hold only judgments/relations (no un-evidenced quantities).
2. P2 done: a gate script rejects an artifact whose claims lack cited evidence (negative test passes).
3. P3 done: one task completes the full loop with all artifacts gated and logged; the round log shows it.

## Disposition options

- **Commit P1** (recommended): design Memory & Context — the next buildable slice.
- **Commit P0 hardening**: first, tighten the foundation (schema-validate logs, inbox triage rules).
- **Adjust the blueprint**: tell me what to change before anything is built.
