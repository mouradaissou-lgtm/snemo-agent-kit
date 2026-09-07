# P1 Proposal — Memory & Context Design (L4 + L5)

> **Status: PROPOSED — awaiting CEO disposition.** Mission cited: "Build the agent architecture" (goal rev 6). This is the *design* for the next buildable slice (Architecture Proposal Part 2, P1). Nothing is implemented until committed.

## L4 — Memory (`04_memory/`)

**Principle (non-negotiable):** memory holds **judgments and relations, never ground-truth quantities.** Derived numbers live in recomputed state, not in beliefs.

### Belief record schema (v0.1)

```
id: M-<seq>
kind: judgment | relation | rule
claim: <one typed statement>
confidence: low | medium | high
maturity: proposed | verified | accepted | superseded
scope: sandbox | <layer-ref>
evidence: [ ref → file@line-or-date, method@version ]
created: <date>
updated: <date>
last_verified: <date | never>
forget_list: [ <condition or date> | none ]
```

### Memory rules

1. A claim without an evidence ref may exist only with `maturity: proposed` + `confidence: low` — never silently upgraded.
2. Numbers: only with `method@version` and recomputed-at state; memory never caches them.
3. Conflicts: resolved via the collision protocol — logged, asked once, resolved.
4. **"Later" does not exist:** every belief's forget_list entry has a date or an explicit discard.
5. Relations: `relates(A, B, kind, since, evidence)` — e.g., purpose→goal→artifact.

## L5 — Context (`05_context/`)

**Principle:** every task starts from a context pack — ORIENT before any data tool call.

### Context pack schema (v0.1)

```
task: <id>
mission_ref: <goal id@revision>
sources: [ <file refs + state snapshot> ]
evidence: [ <claims as cited> ]
open_questions: [ { id, text, disposition: within-rule|beyond-rule, due: <date> } ]
state: <pointer to workspace/log state used>
```

### Context rules

1. A context pack is produced before the first data tool call of a task.
2. Every open question carries a due date or an explicit discard.
3. Stale/missing state is marked **degraded** in the pack — never silently assumed current.

## P2 preview — the gates that will verify this (for the record)

- **G1 claim→evidence:** every claim in a produced artifact cites a source that exists.
- **G2 numbers recomputed:** derived numbers carry `method@version`; no bare assertions.
- **G3 structure:** logs and records validate (the integrity check run this round is G3 on the logs).
- **G4 disposition:** nothing runs without its disposition row in DECISION_LOG.

## Implementation (once committed)

1. Create `04_memory/` + `05_context/` with these schemas as live templates + READMEs.
2. Seed memory with *zero* entries (memory starts empty — judgments only accumulate with evidence).
3. Wire the first real task through a context pack and one belief record as a **test case**, gated by G1–G4.

## Disposition options

- **Commit P1** (recommended): implement as above.
- **Adjust schema** first: tell me what to change.
- **Park:** keep as proposal; I move to P0 hardening (deeper log/tooling validation).
