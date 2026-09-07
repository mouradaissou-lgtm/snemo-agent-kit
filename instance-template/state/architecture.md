# Architecture register — {{INSTANCE_NAME}} instance

> Self-governed register of this SNemo instance. Validated by
> `06_gates/g11_architecture_sync.sh` + `state/validate_architecture.sh`.

version: v1.0
last change: 2026-09-03
last review: 2026-09-03 ({{INSTANCE_NAME}} standalone instance — boot contract propagated)
machinery: {{ROOT}} (Machinery/ subdir — resolved by state/resolve_machinery.sh; gates in 06_gates/)

## Surfaces

| id | surface | path |
|----|---------|------|
| S-01 | Brain front door | AGENT_CORE.md (core root) |
| S-02 | SPEC layer | SPEC/01..05 (identity, platform, behavior, mission layer, writing style) |
| S-03 | Memory system | state/memory/beliefs.md schema · state/memory/MODE |
| S-04 | Graph store | state/graph/ |
| S-05 | Living state tables | state/agenda.md · state/projects.md · state/architecture.md (this file) |
| S-06 | Gates (canonical) | 06_gates/ |
| S-07 | Machinery framework | Machinery/02_framework/ |
| S-08 | Audit logs | Machinery/03_logs/ (DECISION_LOG, DECISION_QUEUE, ROUND_LOG) |
| S-09 | Registry | Machinery/08_rh/ |
| S-10 | Cockpit | Machinery/cockpit/ |

## Change rows

| # | Date | Surfaces | Change | Round | Disposition | Verdict | Notes |
|---|------|----------|--------|-------|-------------|---------|-------|
| ARC-001 | 2026-09-03 | S-01..S-10 | Instance scaffolded | — | — | user — 2026-09-03 validé | fresh standalone instance |
