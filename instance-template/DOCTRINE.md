# DOCTRINE — {{INSTANCE_NAME}} (the instance's rule set)

> This is the **instance-specific doctrine** the engine (`behavior.ts`) points the agent to load at
> boot. It is separate from the generic behavior: the cognitive core is universal; this file holds
> **this instance's** rules — how to read data, how to aggregate, what the model is. Fill the
> placeholders with the domain specifics. The behavior engine stays generic and identical for every
> instance; only this file differs.

---

## 1. Data source (fill per instance)

- **Source:** `<the data source — e.g. a client API, a file share, a DB via gateway, or "none (advisory)">`.
- **Read-only:** `<read-only rules; the allowed verbs; the client constraint (e.g. curl-only/WAF); the auth rule — token never stored, never requested from the user>`.
- **Access tool:** `{{TOOL_FILE}}` — the instance's reader (auto-loads the token; read via it).
- **Model guide:** `{{MODEL_GUIDE}}` — entity map, FK joins, where values live, filters, reliability traps.

## 2. Aggregation rule (the non-negotiable)

> **The source aggregates — never re-implement an engine.**

- If the source exposes a **server-side aggregate / analytic endpoint** (e.g. a `report`/dashboard
  endpoint that sums/group-by server-side), **USE IT** for any aggregate, ranking, cross-tab, or
  total. Do **NOT** implement that aggregation by scanning rows (paging) or writing a dedicated
  engine.
- To compute a metric: use/extend the access tool's generic aggregate (`--by`/group-by/column/expr).
  If the source's aggregate doesn't already cover an entity/measure, **extend the tool's entity → map**
  (data-driven), **never** write a `*_engine.py` that re-implements the aggregation.
- A derived value (sum, ratio, share, projection) is produced by the **engine/tool**, never by the
  LLM; it cites `method@version` and is verified independently (a different aggregated path).
- Before writing any engine/aggregation, **check whether the source or the existing tool already does
  it.** Production-fresh: re-derive live each turn; never re-serve a cached number.

## 3. Authority of this file

- This file is the instance's **doctrine**: follow it before any task that reads data or computes a
  number. The behavior engine supplies the universal loop; this file supplies **this instance's** rules.
- If a rule here conflicts with the generic core, **this file wins for the domain** (it is instance-specific);
  record the divergence in the ledger, never silently.
