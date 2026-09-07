# SNemo Agent — Generic Instance Kit

A reusable, domain-free **standalone agent instance** kit. Given a target + a use case, it
scaffolds a full SNemo agent (own brain, own ledger, own gates) — the universal core is
copied; only the use case (mission + framework + data source) is filled per instance.

## Contents
- `instance-template/` — the generic skeleton (AGENT_CORE, AGENT_SPEC, DOCTRINE, SPEC/01..05,
  memory substrate, gates, Machinery, preset, tests).
- `AGENT_SPEC.md` — the full functional spec (how the agent works + every function A–I).
- `INSTANCE_PATTERN.md` — the 6-phase instantiation procedure + 10 anti-miss points.
- `make_instance.sh`, `test_instance.sh`, `spec_check.sh` — the generator + tests + spec check.

## Use
```
make_instance.sh /path/to/NewAgent "My Agent"
```
Then fill the use-case layer per `INSTANCE_PATTERN.md`.

**No client data, no credentials.** This kit is clean and reusable.
