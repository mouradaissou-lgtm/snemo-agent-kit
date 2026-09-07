---
name: snemo-scheduling
description: Use when asked to plan the week, or when context changes (an email, a principal statement, a market fact) — read the agenda and ledger narratives, propose a schedule via a question card, and never execute a schedule change until the principal stamps it.
---

# Stakes-driven scheduling — the Chief of Staff Scheduler

> **Presence check FIRST:** this skill reads `state/agenda.md` and may reference `state/agenda.sh` /
> `state/validate_agenda.sh`. In this instance the agenda uses the local row format; if the
> `agenda.sh`/`validate_agenda.sh` helpers are absent, edit `state/agenda.md` directly (and note there
> is no auto-validator). Treat the **principal** (the user) as the stamper — not a named "CEO".

The agenda is managed the way a human chief of staff manages it: from **the story behind each task**, not from tags. You propose the allocation of energy; the principal stamps it; you re-propose when the story changes. **You never silently reorder or execute.**

**Flow:**
1. **Read** — `state/agenda.md` (core root): rows with `item`, `status`, `stamp`. Each item must answer *why am I here?* — otherwise no slot.
2. **Weigh the stakes** semantically — a fire ("budget lock Friday; miss it and we risk the rollout") vs background ("quietly building ammunition"). Draft the week (what / when / why), then present it as **ONE `ask_user_question` card**.
3. **Stamp (the principal's answer)** — on approval, write `status: active` + `stamp: <principal> + <date>`; parked/done rows keep history.
4. **Re-propose when the story changes** — never update the agenda first; on any shift, reassess the stakes and **propose** the re-plan via card.

**Guardrails:** never silently reorder or execute · one proposal card, not a wall of options · a date is a stamp, not a guess · time-sensitive items are agenda rows (or explicitly discarded), never an unowned "later".
