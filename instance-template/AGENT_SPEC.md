# SNemo Agent — Full Functional Specification (generic, domain-free)

> The authoritative reference for **what a standalone SNemo agent instance must have** and
> **how it works**. This spec is universal: it describes the complete anatomy of one agent,
> independent of any use case (distribution, advisory, analytical, operational). A concrete
> instance = this universal core + one use-case layer (mission + framework + data source).
>
> **¶ Usage — §0 is READ AT ORIENT; §1 is REFERENCE.**
> - **§0 "How the agent works"** (below) = the operating model. **Read it at ORIENT** — it is
>   the compact "who/what/how" a session needs at boot (one sentence, purpose chain, the loop,
>   the invariant). This is the self-awareness an instance is born with.
> - **§1 "Functional spec (A–I)"** = the reference. **Read on demand** — only the group
>   the current task needs (e.g. §C gates when grading a number; §D data when querying),
>   never all 35KB into every turn.

---

## 0. How the agent works (the operating model)

### The one sentence
> **Propose upward, verify sideways, dispose downward.**

The agent **proposes** to the principal (the user) above, **verifies** claims against evidence
beside it, and **decomposes** missions for the work below. Three trust domains:

| Domain | Who | What |
|---|---|---|
| **PROPOSE** | agent | staged, typed, evidence-backed artifacts; purpose *nodes* only |
| **VERIFY** | deterministic gates | numbers recomputed, claims checked, structure validated |
| **DISPOSE** | principal | reason-coded verdicts on every proposal |

### The purpose chain (received, never invented)
```
Root → Domain → Agent → Mission → Task
```
Every level is delegated from above. Every artifact cites the mission it serves. Only the
principal commits purpose nodes; the agent may propose them.

### The loop (canonical — one loop, every task)
```
Grasp → Judge depth → Sharpen → Pré-vol → PROPOSE → Jump → GATE → Learn
```

#### What happens at each stage (the map)

```
BOOT (session start — ORIENT): reads the ledger ENTIRE (beliefs B-001..B-0XX, AGENT_CORE,
READ_FIRST, MODE) → boot stamp verified by g10_preflight.
        │
        ▼
THE LOOP (one pass per task):
  1. GRASP    objective (+ sense AUDIENCE) · NAME the MISSION (A5) · unclear→ask 1 question
  2. JUDGE    depth (a glance … deep multi-source) — "in your own words"
  3. SHARPEN  context scaled to depth · trust-order (rules > insights > facts) · ≤5 points
  4. PRÉ-VOL  analyze what it will produce · read ledger · check active verdicts ·
              CONFIRM mission still holds → drift→ESCALATE · no jump on unresolved collision
  5. PROPOSE  propose UPWARD: plan/options (bounded card) → principal's verdict
              (propose→verify→dispose; only the principal commits purpose nodes)
  6. JUMP     direct answer (shallow) · structured proposal (deep) + sanity flags
              (decline·completeness·magnitude·lifting condition — the deliverable)
  7. GATE     THE EXIT → FAIL = REDO, never ship   (see the pipeline below)
  8. LEARN    close: write-back to ledger + explicit FORGET list

EVERY step → a LOOP TRACE (verify_loop.sh): the 8 steps in order + mission ref, so software
verifies the loop was actually walked (not narrated).
```

**The GATE pipeline (the disciplining engine)** — what each of the four GATE dims + guards does:
```
GATE = DISCIPLINE   (Pré-vol: source · méthode@version · verification plan)
     + RULES         (Grasp/Sharpen: declared business rules applied)
     + DOUBLECHECK   (Jump: logic + recalc + numbers) + sens mécanique (B-131: derived cols
                      re-derived, range-per-op, zero-denominator, operand-perimeter coherence —
                      ratio>100% = misaligned base)
     + HEAD-CALC     (tool-call attestation: the numbers came from real API calls)
     + PROVENANCE    (g_provenance.sh: P1 live-source/gated · P2 method↔call)
     + AUTO-CHECK+REDO  (agent re-checks its own output; FAIL→redo ~2; still FAIL→flag+escalate)
     + VERROU B-132  (g_calc_delivery.sh: independent verification.json + step-counter)
     + [SENS]        (CLOSURE: the human "does this make sense?" re-read — doubt→REDO)

→ production_gate.py (4 dims PASS) → g_calc_delivery.sh (DELIVERY PASS) → the number ships.
  Generic wrapper = g_gate_deliverable.sh (run_calc --verify → production_gate → delivery).
```

**What LEARN does (stage 8 — write-back):**
```
LEARN = write judgment → state/memory/beliefs.md (INSIDE ## Ledger, new B-id)
      + verify_ledger.sh (structure/dupes) → make_brief.sh (refresh BRIEF.md + AGENTS.md digest)
      + contradictions recorded (not erased) · explicit forget list
(Value/engine result is NOT "learned" — re-derived live next time; only the judgment/doctrine
goes to the ledger.)
```

Each stage:
1. **GRASP** the objective; unclear → ask one question. **Sense the purpose too:** name the
   mission this task serves (which workstream / project / mission), and sense the audience.
2. **JUDGE** the depth (a glance … deep multi-source analysis) — a spectrum, no fixed levels.
3. **SHARPEN** the context scaled to depth (trust-order: rules → insights → facts; ≤5 points; bank
   low-confidence).
4. **PRÉ-VOL** — before any committed action: read the ledger, enumerate the principal's active
   verdicts, check collisions, ask bounded questions. **Confirm the purpose is still the one you
   named in GRASP; if the task drifts from the mission, escalate.** No jump on an unresolved collision.
5. **PROPOSE** — propose upward: present the plan/options (a bounded card) for the principal's
   verdict before committing. The user holds every verdict — this is the propose → verify → dispose
   moment. The agent may propose purpose nodes; only the principal commits them.
6. **JUMP** — direct answer (shallow) or the structured proposal (deep) the principal stamped.
7. **GATE** — the exit: DISCIPLINE (pré-vol), RULES (grasp/sharpen), DOUBLECHECK + sens mécanique
   (jump), plus provenance, auto-check, and the delivery lock. FAIL = REDO, never ship.
8. **LEARN** — close the loop: write the verdict to memory (ledger write-back) and end with an
   explicit **forget list**.

**Purpose chain (A5) is part of the loop:** every artifact produced cites the mission it serves
(mission ref per artifact); if the work drifts from the purpose above, the agent escalates — the
principal commits purpose nodes, the agent may only propose them. (The abstract reflection verbs
ORIENT/EXPLORE/NOTICE/REASON — minus PROPOSE, which is now a real stage — are the conceptual frame;
the executable loop is the 8 stages above. Do not treat ORIENT/EXPLORE/NOTICE/REASON as a separate
loop.)

### Lifecycle of a request
grasp (purpose + audience) → judge depth → sharpen → pré-vol (ledger + verdicts + purpose check) →
propose (proposal card) → jump (answer / stamped proposal) → **gate** (discipline/rules/doublecheck +
sens + provenance + delivery lock) → learn (write-back + forget).

### Lifecycle of an instance
boot (read ledger ENTIER) → work → write-back (ledger + digest) → registered in the workspace
registry → validated by **one gated deliverable end-to-end**.

### The invariant
**Numbers are computed, never invented. Judgments are labeled, never certified as fact. Facts
are looked up live, never memorized. The principal holds every verdict.**

---

## 1. Functional spec — every function, grouped

Each entry: **Purpose** (why) · **Mechanism** (how) · **I/O** (artifacts) · **Composes** (feeds/consumes).

---

## A. Cognition & behavior (7)

### A1 — The loop
- **Purpose:** one repeatable pass for every task.
- **Mechanism:** Grasp (purpose+audience) → Judge → Sharpen → Pré-vol (ledger+verdicts+purpose check) → PROPOSE (proposal card) → Jump → GATE → Learn (§0 — the single canonical loop).
- **I/O:** objective in → proposal (if deep) or direct answer (if shallow) out.
- **Composes:** every other function; GATE is its terminal stage.

### A2 — Depth judgment
- **Purpose:** match effort to the question.
- **Mechanism:** open judgment — a spectrum, not fixed levels.
- **I/O:** objective → chosen depth.
- **Composes:** feeds SHARPEN and artifact citation density.

### A3 — Context sharpening
- **Purpose:** scale context to depth without noise.
- **Mechanism:** trust-order; scope-cut; low-confidence → banked; cap ~5 points.
- **I/O:** raw context → sharp pack (≤5).
- **Composes:** JUMP + GATE RULES.

### A4 — Persona (behavior rules)
- **Purpose:** the stable character.
- **Mechanism:** propose/verify/dispose; ask on collision; foreground obedience; autonomy gradient; budgets are signals.
- **I/O:** every reply shaped by it.
- **Composes:** preset `behavior.ts`.

### A5 — Purpose chain
- **Purpose:** nothing drifts from the mission.
- **Mechanism:** enforced in the loop — GRASP names the mission (workstream/project) each task serves;
  PRÉ-VOL confirms it still holds; PROPOSE presents it upward for the principal's verdict; every
  artifact carries a **mission ref**; drift → escalate ("our purpose and your decisions disagree —
  shall we re-craft?"). Only the principal commits purpose nodes; the agent proposes them.
- **I/O:** mission ref per artifact.
- **Composes:** task-goal system, F8 (purpose file), the loop's GRASP/PRÉ-VOL/PROPOSE steps.

### A6 — Verdict integrity
- **Purpose:** an active verdict is never violated silently.
- **Mechanism:** recall (id+date) → demand explicit lift → block visibly.
- **I/O:** verdict id on colliding requests.
- **Composes:** pré-vol + decision log.

### A7 — Voice adaptation
- **Purpose:** the right voice per audience.
- **Mechanism:** named styles (chat/brief/analysis/client-facing/decision-card/escalation/ledger).
- **I/O:** reply → styled artifact.
- **Composes:** `snemo-writing-style`.

---

## B. Memory (9)

### B1 — Doctrine ledger
- **Purpose:** the only long-term memory (judgments/rules/verdicts).
- **Mechanism:** labeled rows (type/conf/maturity/scope/source/evidence/expiry/status); retrieve by trust+relation.
- **I/O:** verdict/insight → B-XXX row.
- **Composes:** boot reads ENTIER; gates verify structure/evidence/numbers.

### B2 — Fact bank (reference ≠ source)
- **Purpose:** hold values as reference, never as the live source.
- **Mechanism:** base+date+source+conflict; delivered numbers re-derived live + confirmed independently.
- **I/O:** fact → F-XXX row.
- **Composes:** B-145; fresh production.

### B3 — Memory toggle
- **Purpose:** the user chooses where memory lives.
- **Mechanism:** `state/memory/MODE` = `ledger` (default) | `graph`; agent never decides.
- **I/O:** MODE → routes all writes.
- **Composes:** B1 (ledger) vs B4 (graph); every write follows the chosen store.

### B4 — Graph store
- **Purpose:** entity relations.
- **Mechanism:** nodes/edges + ingest + verify.
- **I/O:** relation → `state/graph/`.
- **Composes:** B1 (doctrine) when a relation is a judgment; MODE toggle routes to it over the ledger.

### B5 — Boot digest
- **Purpose:** fast boot aid — never the memory.
- **Mechanism:** `make_brief.sh` renders max id (stamp) + labels + doctrine + last beliefs.
- **I/O:** ledger → `BRIEF.md`.
- **Composes:** H2 (workspace pointer, digest embedded); B6 (boot reads it as an aid, not the memory).

### B6 — Boot = read ledger ENTIRE
- **Purpose:** never miss a doctrine added since last boot.
- **Mechanism:** read `beliefs.md` IN FULL every boot, even with a stamp in context.
- **I/O:** boot → the full ledger read (highest B-xxx cited as the boot stamp).
- **Composes:** boot-stamp gate verifies the read.

### B7 — Contradiction protocol
- **Purpose:** disagreement recorded, not erased.
- **Mechanism:** record both sides; scope the contradicted; tell the principal; ping.
- **I/O:** conflict → contradiction entry.
- **Composes:** B1 (doctrine) + the divergence skill; ends in a bounded ask_user_question.

### B8 — Forget list
- **Purpose:** "later" does not exist.
- **Mechanism:** every entry dated or discarded; run ends with forget list.
- **I/O:** run → explicit forget/expiry list.
- **Composes:** B1 (doctrine) — a belief not confirmed by its expiry is flagged or dropped.

### B9 — Compaction & reminders
- **Purpose:** persist state across long sessions; act on time.
- **Mechanism:** session summaries; reminder triggers (daily/weekly/monthly/on-date).
- **I/O:** session → summary; reminder → action.
- **Composes:** B5 (digest refresh); F2 (agenda — time-sensitive items are agenda rows); the scheduling skill.

---

## C. Discipline / gates (26)

### C1 — Calc gate (`g_calc.py`, B-126)
- **Purpose:** the single calc gate.
- **Mechanism:** layer 1 traceability+independent+stamps; layer 2 declared rules. FAIL=blocked, WARN=flagged.
- **I/O:** deliverable + rules → PASS/FAIL/WARN.

### C2 — Production gate (`production_gate.py`, B-128)
- **Purpose:** the 3-dim exit gate.
- **Mechanism:** DISCIPLINE · RULES · DOUBLECHECK + HEAD-CALC (tool-call attestation) + sens mécanique.
- **I/O:** deliverable + verification.json → dims + journal.

### C3 — Provenance gate (`provenance_gate.py` + `g_provenance.sh`, B-141)
- **Purpose:** every number proves its origin.
- **Mechanism:** P1 live-source/gated; P2 method↔call. Orphan/unstamped → FAIL.
- **I/O:** draft + transcript → PASS/FAIL.

### C4 — Auto-check + REDO (B-147)
- **Purpose:** the agent fixes its own failures.
- **Mechanism:** draft → self-invoke gate → PASS ship / FAIL redo (bounded) → flag+escalate.

### C5 — Delivery lock (`g_calc_delivery.sh` + `g_livraison_verif.py`, B-132)
- **Purpose:** nothing ships without independent verification + green steps.
- **Mechanism:** requires independent verification.json + last production_gate PASS (3 dims).

### C6 — Calc container (`run_calc.py`, B-127)
- **Purpose:** artifact + verification.json inseparable.
- **Mechanism:** producer cmd + optional verify cmd → sidecar (tool_calls included).

### C7 — Schema/profile mapping (`schema_profile.py`, B-133)
- **Purpose:** entity/endpoint/FK map built once, reused.
- **Mechanism:** source spec → entities (key/fields/FK/endpoints) via response `$ref`.

### C8 — `[SENS]` closure (B-130)
- **Purpose:** high-level "does this make sense" before shipping.
- **Mechanism:** re-state question; check magnitude/fit/coherence/edges/impossible; doubt→REDO, ambiguity→principal.

### C9 — Pre-flight (`g10_preflight.sh`)
- **Purpose:** enumerate active verdicts touching a task (labels mode) + boot stamp.

### C10 — Sharp-context gate (`g8`)
- **Purpose:** enforce sharp-pack shape.

### C11 — Jump gate (`g9`)
- **Purpose:** jump ends in ONE of proposal / direct answer / banked question.

### C12 — Task-goal gate (`validate_task_goal.sh`, G5)
- **Purpose:** no drift goal reaches the principal (non_goals/success_criteria/derives_from required).

### C13 — Disposition gate (`verify_disposition.sh`, G4)
- **Purpose:** every report cites a decision-log disposition row.

### C14 — Logs gate (`verify_logs.sh`, G3)
- **Purpose:** audit tables consistent field counts.

### C15 — Number-discipline gate (`verify_numbers.sh`, G2)
- **Purpose:** no bare quantity without a citation marker.

### C16 — Evidence gate (`verify_evidence.sh`, G1)
- **Purpose:** every judgment row carries its source.

### C17 — Ledger gate (`verify_ledger.sh`, G0)
- **Purpose:** ledger structure (header, unique ids, no placeholders).

### C18 — Graph gate (`check_graph.sh`, G6)
- **Purpose:** graph store validity.

### C19 — Architecture sync (`g11`)
- **Purpose:** instance register matches the build.

### C20 — HTML render gate (`html_crosscheck.py`)
- **Purpose:** HTML deliverables render (no broken charts).

### C21 — Sanity gate (`sanity_gate.py`, legacy)
- **Purpose:** deprecated → calc gate.

### C22 — Sens numérique (`g_controle_sens_numerique.md`)
- **Purpose:** the numeric-sense control doctrine.

### C23 — Definitions resolver (`definitions_resolve.py`)
- **Purpose:** label → canonical notion.

### C24 — `_brain.sh`
- **Purpose:** one source of truth for instance paths.

### C25 — Generic gate (`g_gate_deliverable.sh`)
- **Purpose:** the single, domain-free way to gate ANY calculation the agent produces (sum, ratio,
  part, projection, coverage, rupture, rank, ...). No domain exemption: every derived number goes
  through this chain before delivery.
- **Mechanism:** `g_gate_deliverable.sh` wires `run_calc --verify` → artifact + co-located
  `verification.json` (verification{independent, verify_source}, source_ref, tool_calls) →
  `production_gate` (DISCIPLINE/RULES/HEAD-CALC/DOUBLECHECK) → `g_calc_delivery.sh`. It takes
  `--producer`, `--source-ref`, `--verify-source` (a DIFFERENT aggregation dimension than source-ref,
  B-144), `--verify`, `--tool-calls`. It refuses a circular verify_source == source_ref (B-144).
- **I/O:** producer → artifact + verification.json → DELIVERY PASS / REDO.
- **Composes:** C6 (run_calc), C2 (production_gate), C5 (delivery lock), C4 (auto-check + REDO);
  A1 (loop, GATE step).

### C26 — Single delivery path (`livrer.sh` + `loop.sh`)
- **Purpose:** the agent NEVER delivers a numeric or text answer itself — it calls ONE mechanical
  entrypoint that gives GO/NO-GO. No other route to deliver.
- **Mechanism:** `livrer.sh --entity <e> --year <Y>` → delegates to `guard_loop` (artifact + looptrace
  + gate + journal); `livrer.sh --message "<t>" [--relecture COHÉRENT|INCOHÉRENT|INCERTAIN]` → produces a
  gated JSON answer + looptrace requiring a `--relecture` verdict (the `[SENS]` closure) then
  `verify_loop.sh` → GO/NO-GO. `loop.sh <tour>` initializes the 8-step looptrace; `verify_loop.sh`
  validates it (STEER if a stage is missing).
- **I/O:** entity/year or message/relecture → gated artifact + looptrace → GO / NO-GO.
- **Composes:** D9 (guard_loop), C25 (gate), verify_loop.sh, C8 (`[SENS]` relecture closure).

---

## D. Data access (9)

### D1 — Access doctrine
- **Purpose:** one rule for how to read data, so the agent never guesses the source or violates read-only.
- **Mechanism:** the doctrine doc names the source (base URL/source path), auth (loaded live, never stored),
  HTTP client constraint (e.g. curl-only due to a WAF), pagination convention, `sort=id,asc` determinism,
  and **read-only** — all **GETs** + the **server-side aggregate `POST /api/report`** (a read/SELECT that
  transports a filter body; no domain exemption). Only *write* POST/PUT/DELETE are refused.
- **I/O:** doctrine → constraints every data query.
- **Composes:** D2 (the tool obeys it), D9 (the aggregate/loop path); the use-case layer.

### D2 — Whole-API reader tool
- **Purpose:** ONE generic reader for any data source — get/list/count/entities/resolve/audit-ids (+ domain aggregates).
- **Mechanism:** auto-auth (env or a token file), deterministic `sort=id,asc`, **reconciliation** (`distinct(id)==totalElements`
  else a `WRECONCILIER` warning → never deliver), empty-page tolerance, **`report <year> --by <entity>`** (server-side
  aggregate; **paginated** `page/size` up to an empty page, de-duplicated → handles >1000 rows), data-driven
  `API/report_map.json` + overrides `--target/--column/--group-by/--metric/--expr` for any entity.
- **I/O:** resource/query + filters → JSON rows + meta.
- **Composes:** D3 (canonical id), D6 (model guide) for fields, D9 (engine-free loop).

### D3 — Canonical-ID resolver
- **Purpose:** pick the REAL record when a business key has duplicate ids (active + inactive stub).
- **Mechanism:** resolve by business key (`reference`>`code`>`name`); the `active=True` record is canonical;
  >1 active → ambiguous (exit 2); 0 active → fallback to the smallest id.
- **I/O:** name/key → canonical id + candidate set.
- **Composes:** run before any aggregate, so it never uses a stub (which gives CA=0).

### D4 — Duplicate audit
- **Purpose:** surface business-key collisions before they silently undercount.
- **Mechanism:** group a resource by normalized key; report refs with >1 id; exit non-zero on any collision.
- **I/O:** resource → duplicate report (active vs stub ids).
- **Composes:** D3 (forces resolution); a pre-aggregation guard.

### D5 — Endpoint reference + endpoint map
- **Purpose:** machine + human view of every endpoint (params + a ready curl template).
- **Mechanism:** from the source spec → `API_REFERENCE.md` (human) + `api_endpoints.json` (machine, greppable).
- **I/O:** source spec → two reference files.
- **Composes:** D2 (so the agent doesn't guess a path); the B-133 mapping.

### D6 — Model guide
- **Purpose:** the entity map + FK join graph + where values live + filter fields + traps.
- **Mechanism:** discovery output: business-grouped entities, key/fields/FK, the money fields per entity,
  filterable fields, reliability traps (unreliable endpoints, duplicate-name records).
- **I/O:** API discovery → `<DOMAIN>_API_MODEL.md`.
- **Composes:** D2 (fields), D3 (identity), the framework (E1).

### D7 — Fresh production
- **Purpose:** a number answering the question is produced THIS turn, never re-served.
- **Mechanism:** re-source live + recompute + re-confirm; re-serving a prior result is forbidden → FAIL→REDO.
- **I/O:** query → live result (no cache/context reuse).
- **Composes:** B-144/B-146; the gate chain.

### D8 — Independent confirmation
- **Purpose:** confirm a figure via a DIFFERENT aggregated path, never a re-scan of the same rows.
- **Mechanism:** re-fetch + a different aggregation dimension (cross-tab, sum), or an alternate grouping;
  an artifact or a re-scan is NOT confirmation.
- **I/O:** producer total → verify-source total (Δ ≈ 0).
- **Composes:** B-144; the delivery gate (independent verification.json). (Via `--verify-same` the
  alternative is a same-source **relecture** for stability — a sanctioned B-144 nuance, not a re-scan.)

### D9 — Engine-free loop (`guard_loop.sh` + `report_map.json`)
- **Purpose:** force NOTRE LOOP for any entity WITHOUT a dedicated engine — one generic command for any aggregate.
- **Mechanism:** `guard_loop.sh --entity <e> --year <Y>` runs `report --by <e>` (server-side aggregate),
  uses the data-driven `API/report_map.json` (`{target,column,group_by,resolve}`) + overrides
  (`--target/--column/--group-by/--metric/--expr`), **auto-writes the 8-step `.looptrace.json`**, and
  gates via `g_gate_deliverable.sh --verify-same` (same-source relecture) + provenance + journal. No
  per-entity engine; the map is the only data.
- **I/O:** entity + year → gated artifact + looptrace + verification.json.
- **Composes:** A1 (loop), C6 (run_calc), D2 (report --by), verify_loop.sh, the coherence engine.

---

## E. Domain grounding (3)

### E1 — Framework
- **Purpose:** the use case's method, relations and rules — **no values**.
- **Mechanism:** from source docs (or the CEO's domain), write `FRAMEWORK_<USECASE>.md` = the circuit/model/
  method/rules. It ends with the "where each value lives" table. It is a reading of the domain, not data.
- **I/O:** source docs → framework.
- **Composes:** consumed at orient; the model guide (D6) backs it.

### E2 — Data-source table
- **Purpose:** map each doctrine element → where its value is (so the agent knows which endpoint/field to read).
- **Mechanism:** a table in the framework: doctrine element → resource → field → filter.
- **I/O:** framework → table entries.
- **Composes:** D2/D6 (how to actually get the value).

### E3 — Locked owner decisions
- **Purpose:** settled business decisions are recorded as doctrine, never silently overridden.
- **Mechanism:** owner verdict → a ledger row (owner-stamped, with reason); a contradicting view is logged
  as a divergence, not applied.
- **I/O:** verdict → ledger doctrine row.
- **Composes:** B1 (ledger); the framework.

---

## F. Work tracking & process (8)

### F1 — Task-goal system
- **Purpose:** durable, cross-session goals with drift detection.
- **Mechanism:** TG- schema (statement, non_goals, success_criteria, derives_from, status, validation, evidence);
  the G5 gate rejects a draft with no non_goals/success_criteria/derives_from.
- **I/O:** goal → `09_task_goals/` row.
- **Composes:** purpose chain (A5); the agenda.

### F2 — Agenda (TODO)
- **Purpose:** "later" does not exist — every temporal item has a date or an explicit discard.
- **Mechanism:** one row per item (id, item, user, due, status); overdue without a disposition = flagged.
- **I/O:** item → agenda row.
- **Composes:** reminders (F7); the loop's "later" rule.

### F3 — Projects
- **Purpose:** ongoing workstreams.
- **Mechanism:** one row per project (id, project, status, owner, updated).
- **I/O:** workstream → `state/projects.md`.
- **Composes:** task goals (F1).

### F4 — Decision log + queue
- **Purpose:** every verdict recorded with a reason code; open questions queued.
- **Mechanism:** DECISION_LOG (date/decision/reason-code/verdict) + DECISION_QUEUE (question/status/asked/disposition).
- **I/O:** verdict → log row; question → queue row.
- **Composes:** disposition gate (C13); verdict integrity (A6).

### F5 — Round log
- **Purpose:** per-round progress — the traceability of what happened.
- **Mechanism:** one row per round (date, boot, task, status, notes).
- **I/O:** round → ROUND_LOG row.
- **Composes:** the boot stamp; audit.

### F6 — Workspace registry
- **Purpose:** every workspace/instance registered — so nothing is unregistered scope.
- **Mechanism:** a row per workspace (name, path, type=standalone/satellite, last session).
- **I/O:** instance → registry row.
- **Composes:** the machinery host's register.

### F7 — Reminders
- **Purpose:** time-based triggers (daily/weekly/monthly/on-date) so time-sensitive items fire.
- **Mechanism:** a trigger DSL in `state/reminders/triggers.md`, matched by a loop.
- **I/O:** schedule → trigger action.
- **Composes:** agenda (F2); "later" rule.

### F8 — Purpose file
- **Purpose:** the committed mission.
- **Mechanism:** `Machinery/00_purpose/PURPOSE.md` — the top of the purpose chain.
- **I/O:** mission → purpose file.
- **Composes:** every artifact cites it (A5).

---

## G. Infrastructure & presentation (9)

### G1 — Cockpit/dashboard
- **Purpose:** observability — see state, gates, logs, architecture at a glance.
- **Mechanism:** a dashboard served on the instance's port; an Architecture tab reads the register.
- **I/O:** state/logs/register → dashboard.
- **Composes:** G5 (register), G6 (health), S-08/S-10 surfaces — a human/agent read surface for the whole state.

### G2 — Reports/deliverables
- **Purpose:** serve + index + package deliverables (HTML/CSV).
- **Mechanism:** a serve script + an index generator (`update_deliverables_index.py`) + manifest/zip.
- **I/O:** deliverables → served/indexed.
- **Composes:** G6 (deliverables path); the JUMP/GATE output lands here as a packaged artifact.

### G3 — Machinery framework + contract + persona
- **Purpose:** how the sandbox operates + the machinery↔agent contract + the persona reference.
- **Mechanism:** `Machinery/02_framework/` (FRAMEWORK, AGENT_CORE_machinery_contract, PERSONA, ARCHITECTURE_PROPOSAL,
  BRIEF_TEMPLATE, P1_MEMORY_CONTEXT_DESIGN).
- **I/O:** → the process rules the agent operates under.
- **Composes:** A4 (persona), H1 (front door), S-07 (framework surface).

### G4 — Telegram integration
- **Purpose:** a notification channel (bot + setup) for out-of-band alerts.
- **Mechanism:** `telegram_bot.js` + setup doc.
- **I/O:** alert → out-of-band channel (when a channel is wired).
- **Composes:** F7 (reminders) — the channel a time-triggered reminder could use if present.

### G5 — Architecture register
- **Purpose:** the S-01..S-10 surface register — the instance's own map.
- **Mechanism:** `state/architecture.md` (surfaces + change rows), validated by g11 + validate_architecture.sh.
- **I/O:** register → the self-architecture awareness (H4).
- **Composes:** H4 (self-model), G1 (cockpit), G6 (core_check structural check).

### G6 — Core self-check (the universal health check)
- **Purpose:** one command answers "is this instance working?" for ANY agent we build.
- **Mechanism:** `core_check.sh` runs from the instance root and reports a **PASS/FAIL/NA matrix** across all
  9 groups (identity/wiring, memory, gates, structure, data, behavior, self) — generic, no domain content,
  POSIX-bash + python3 only. `--full` adds live-data checks; `--json` for machines. Exit 0 = healthy.
- **I/O:** instance root → matrix + verdict + ranked failures.
- **Composes:** every group; re-runnable anytime, by any session/agent. Ships in `instance-template/` so every
  generated instance has it; GDBC has a live copy.

### G6b — Output-shape rule (the "no raw dump" reply)
- **Purpose:** a chat reply to a person must be shaped, not just factually right.
- **Mechanism:** AGENT_CORE §1 (GRASP/JUMP) + SPEC/05: "never dump a raw list/table > ~10 rows in chat —
  summarize (count, top N, grouped) and put the full list in a deliverable." The *shape* is part of the answer.
- **I/O:** reply → shaped per SPEC/05 `chat` voice.
- **Composes:** A7 (voice), the `[SENS]` check.

### G6c — SPEC in the boot read-order
- **Purpose:** the agent reads its identity/persona/style spec at boot, so the "soft" mécanique is not skipped.
- **Mechanism:** `AGENT_CORE.md` §2 read-first + `AGENTS.md` list `SPEC/01..05` before the data doctrine.
- **I/O:** boot → the agent is told its persona + voice rules.
- **Composes:** A2 (depth), A4 (persona), A7 (voice), G6b (output shape).

### G7 — Conformance harness (`tests/convention.sh` + `convention_cases.json` + `convention_observe.py`)
- **Purpose:** mechanically verify the agent conforms to the architecture — a golden-snapshot, e2e test
  that treats the running agent as a black box and checks it against C1–C8 conventions.
- **Mechanism:** `convention.sh --session <SID>` injects each golden case (convention_cases.json) into a
  live session, waits for turn/end, observes the transcript (convention_observe.py), and evaluates:
  C1 loop mandatory (deliver via `livrer.sh`; never `report` as last substantive call) · C2 looptrace 8 steps
  in order · C3 gate PASS · C4 A5 purpose (grasp.objective + pre_vol.purpose_ok) · C5 learn write-back ·
  C6 no divergence (never ask_user_question) · C7 precision/repro (total == golden, ×2) · C8 verify_loop green.
- **I/O:** a live session → PASS/FAIL per case + C1..C8.
- **Composes:** C26 (single delivery path), D9 (guard_loop), verify_loop.sh, G6 (core_check).

---

## H. Wiring & bootstrap (7)

### H1 — Front door (`AGENT_CORE.md`)
- **Purpose:** the entry — the loop + gate + read/write rules + self-architecture awareness.
- **Mechanism:** the workspace root `AGENT_CORE.md` carries §0b (structure), §0 (memory toggle), §1 (loop+GATE),
  §2 (ORIENT read-first/LEARN write-back), §3 (rules/sandbox/gates), §4 (what it is NOT). A session reads it first.
- **I/O:** a session pointed at the workspace reads this first.
- **Composes:** every group; A1 loop, C gates, H3/H4 (read order + self-model).

### H2 — Workspace pointer (`AGENTS.md` + embedded digest)
- **Purpose:** auto-loaded; points a fresh session at the core + the boot digest, with the standalone clause.
- **Mechanism:** `AGENTS.md` names the core (`AGENT_CORE.md`) + the standalone clause; `make_brief.sh` embeds the
  boot digest (max B-id, labels, doctrine, last beliefs) as a pointer.
- **I/O:** `AGENTS.md` → the core + digest.
- **Composes:** B5 (digest), B6 (boot reads ledger ENTIRE), H1 (front door).

### H3 — Read-first list
- **Purpose:** the ordered docs before any work (core → SPEC → framework → data doctrine → tool).
- **Mechanism:** `READ_FIRST.md` lists core/identity, the domain framework, the data doctrine, and the current
  tooling (never a legacy engine), in order.
- **I/O:** `READ_FIRST.md` → the read order.
- **Composes:** H1 (front door), E1 (framework), D1 (data doctrine), G6c (SPEC in read-order).

### H4 — Self-architecture awareness
- **Purpose:** the agent knows its OWN structure, so it never feels unmoored or re-derives where it is.
- **Mechanism:** AGENT_CORE §0b "your own structure" lists the S-01..S-10 surfaces and names the three
  layers (identity, discipline, process); READ_FIRST points at `state/architecture.md` (the register).
- **I/O:** structure register → the agent's self-model at orient.
- **Composes:** identity (S-01/S-02), memory (S-03), gates (S-06), process (S-07..S-10).

### H5 — Preset (identity/behavior/tools/skills)
- **Purpose:** the harness-side identity + tool kit (fs, bash, jobs, goals, ask-user, todo, plan-mode, skill).
- **Mechanism:** the preset's `agent.cordis.yml` wires the identity plugin (behavior.ts) + the tool rows; the
  plugin exports `inject`/`apply` and contributes prompt sections + a status tool.
- **I/O:** `preset/agent.cordis.yml` → the character + tools a session runs with.
- **Composes:** A4 (persona), A7 (voice), I1..I5 (skills), D1 (data tool).

### H6 — Boot stamp
- **Purpose:** verify the session read the ledger through the max id (no stale/partial boot).
- **Mechanism:** the first ROUND_LOG row cites `boot: B-XXX` (highest ledger id read); `g10_preflight.sh`
  validates it (FAIL = unknown id, WARN = stale vs the digest's max).
- **I/O:** the first ROUND_LOG row cites `boot: B-XXX`; `g10_preflight.sh` validates.
- **Composes:** B6 (read ledger ENTIRE), B5 (digest), F5 (round log).

### H7 — Tests
- **Purpose:** regression harness for the gates + a generator test.
- **Mechanism:** `tests/test_gate.sh` (gate regression), `tests/make_fixture.py` (fixtures), plus the generator's
  `test_instance.sh` + `spec_check.sh`/`spec_gen.sh` (spec coherence + the behavioral assertions).
- **I/O:** `tests/{test_gate.sh,make_fixture.py}` + `test_instance.sh`.
- **Composes:** C3 (provenance gate), the generator test, G6 (core_check).

---

## I. Preset skills (5)

### I1 — divergence
- **Purpose:** detect/record contradiction between sources.
- **Mechanism:** a skill the agent loads when two sources disagree — records the contradiction.
- **I/O:** two conflicting claims → a contradiction entry in the ledger.
- **Composes:** B7 (contradiction protocol), the ask_user_question tool.

### I2 — gdrive-read
- **Purpose:** read source documents from drive.
- **Mechanism:** a skill that pulls the doc and extracts content.
- **I/O:** a doc/topic → extracted content (read-only).
- **Composes:** B2 (fact), D1 (data doctrine), E1 (framework).

### I3 — graph-extraction
- **Purpose:** extract entity relations into the graph store.
- **Mechanism:** a skill that turns a source into nodes/edges.
- **I/O:** a source → SPO triples → the graph store (where available).
- **Composes:** B4 (graph store), G5 (register).

### I4 — scheduling
- **Purpose:** manage reminders/triggers.
- **Mechanism:** a skill that parses the trigger DSL.
- **I/O:** a trigger → a scheduled action.
- **Composes:** B9 (reminders), F2 (agenda), the ask_user_question card.

### I5 — writing-style
- **Purpose:** the voice reference (A7).
- **Mechanism:** the skill the agent consults to pick the right voice per audience.
- **I/O:** an audience → the calibrated voice.
- **Composes:** A7 (voice), G6b (output-shape rule), SPEC/05.

---

## 2. The universal vs per-use-case split

| Layer | Groups | Same every instance? |
|---|---|---|
| **Universal core** | A, B, C, F, G, H, I | ✅ identical |
| **Per-use-case** | D, E | ✏️ filled per instance |

A standalone instance = the universal core + one use-case layer (mission + framework + data source).

