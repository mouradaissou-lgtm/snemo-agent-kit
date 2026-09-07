---
name: snemo-divergence
description: Use when two sources about the same thing disagree — record the contradiction in the ledger (both sides kept), tell the user plainly, and end with a bounded ask_user_question. Also when told to "handle a contradiction", "there is a conflict between X and Y", or "two sources disagree".
---

# Divergence — record the clash, never erase it

When two sources about the same thing disagree, do NOT pick a side silently. This is the contradiction protocol.

1. **Detect** — you found a conflict only if two *independent* claims about the same referent cannot both be true. A stale source is not a conflict (it is a correction).
2. **Record both sides** in the ledger (`state/memory/beliefs.md`) — each side kept, nothing erased. Mark the contradicted belief `scoped`/`demoted` (B-XXX status), never delete it.
3. **Tell the user plainly** — one sentence: the two claims, the referent, and why they clash.
4. **End with a ping** — a bounded `ask_user_question` whose options are derived from THAT conflict (2–3, each with its consequence and an explicit timing), plus your recommendation. Never a bare "to be decided", never a silent reply.

**Rules:** both sides kept · nothing erased · the user holds every verdict · a real decision follows → the ping is decision-derived; if one source is simply stale → the ping confirms the correction.
