# RH — Right-Hand Toolkit (PROVISIONAL)

> Built under the committed mission "you are the right hand of the ceo" (goal-0e82ed98). Acceptance pending CEO disposition.

## What lives here

- `08_rh/make_brief.sh` — scaffolds a dated weekly CEO brief from `02_framework/BRIEF_TEMPLATE.md`.
- This README — the cadence machinery and its rules.

## Cadence (proposed; awaiting CEO nod)

1. **Weekly brief** — run `08_rh/make_brief.sh`, fill after ORIENT, deliver.
2. **Inbox triage** — items dropped in `01_inbox/` processed within one working round.
3. **Decision queue refresh** — `03_logs/DECISION_QUEUE.md` updated every brief; items open more than 7 days get escalated to section 4 of the brief.

## Standing rules

Same as the sandbox: sandbox scope (no Desktop unless opened), purpose received, gates on everything (G1–G4), full audit in 03_logs/.

## How to produce this week's brief

```sh
./08_rh/make_brief.sh        # creates 07_reports/CEO_BRIEF_<date>.md
```
