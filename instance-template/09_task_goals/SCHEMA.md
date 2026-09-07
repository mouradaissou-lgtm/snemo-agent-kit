# Task-Goal Schema v1.0

```
id: TG-<seq>
title: <short name>
level: mission | task
statement: <one falsifiable sentence — the objective>
derives_from: <path to the purpose/goal it serves>
for_whom: <who this serves>
non_goals: [ NOT …, NOT … ]          # mandatory — the drift detector
success_criteria: [ … ]              # mandatory — the "done"
source: user-given | agent-proposed
status: proposed | validated | planned | active | completed | superseded | abandoned
validation: { stamped_by, date, notes }   # required once status ≥ validated
plan_ref: <path to plan artifact | none>
todo_ref: <path to todo/agenda artifact | none>
evidence: [ ref → file@date, method@version ]
created: <date>
updated: <date>
```

## Field rules
- `statement`: one falsifiable sentence.
- `non_goals`: mandatory and non-empty.
- `success_criteria`: mandatory and non-empty.
- `derives_from`: must resolve to an existing purpose/task_goal.
- `source`: `user-given` (top-down) or `agent-proposed` (requires validation).
- `status` transitions (only the user moves out of `proposed`): proposed → validated → planned → active → completed | abandoned | superseded.
- `plan_ref`/`todo_ref`: references, never embeds.

## The G5 gate
`06_gates/validate_task_goal.sh <draft>` checks required fields, non-empty non_goals/success_criteria, valid source/status, resolves derives_from, and a validation stamp for non-proposed status.
