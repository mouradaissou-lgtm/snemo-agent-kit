---
name: snemo-gdrive-read
description: Use when asked about Google Docs / Google Drive / Google Calendar content — search Drive for documents, READ their content, and judge what changes a decision into the ledger. Read-only always. Also when told to "check the drive", "find the doc about X", "read the spec", or "look at the calendar".
---

# Google Drive / Calendar — read-only document access

This connection is **READ-ONLY** — the OAuth scope is `drive.readonly` + `calendar.readonly` only; nothing in this flow can write to Drive. Credentials live at the instance's private store (`~/.dsh/private/gdrive_creds.env`, root-only) — never paste or echo raw credential values.

> **Presence check FIRST:** this skill requires the Drive tooling to be present in the workspace
> (`<workspace>/Files /gdrive/` scripts: `gdrive_search.sh`, `gdrive_fetch.sh`, `gcal_fetch.sh`). If
> they are absent, do NOT assume them — load the instance's data-reader skill for data questions and
> report that Drive access is not wired here.

**Usage pattern (only if the tooling is present):**
1. `bash "<workspace>/Files /gdrive/gdrive_search.sh" <topic words...>` — find the doc.
2. `bash "<workspace>/Files /gdrive/gdrive_fetch.sh" <file-id-or-url> [md|txt]` — read its content.
3. `bash "<workspace>/Files /gdrive/gcal_fetch.sh" [start-date] [end-date]` — read calendar events.
4. Judge what changes a future decision → record it in the ledger, tagged with source. Never save a raw file; never write to Drive.

**Guardrails:** read-only · never echo credentials · only the judgment that changes a decision goes to memory · everything logged and auditable.
