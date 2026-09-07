# Cockpit — instance

> Tableau de bord / observabilité mécanique de l'instance (aucun domaine).

- `dashboard_server.js` — serveur HTTP (port via `DSH_PORT`, défaut 8003 ; racine de
  l'instance via `DSH_INSTANCE_DIR`, défaut = le parent du dossier `Machinery/`).
- `dashboard.html` — vue web : lit `/monitor` (état des livrables + gates + santé)
  et `/spec` (conformité contre AGENT_SPEC.md) via `fetch`.
- `monitor.py` — backend JSON : journal de conformité (`06_gates/journal_conformite.jsonl`),
  `core_check.sh --json` (G6 santé universelle) + matrice de couverture
  (`tests/spec_coverage.json`). Fail-soft, aucun domaine.
- `observability/` — surface d'observabilité fine (stub, port via `DSH_OBS_PORT`, défaut 7788).

## Lancer

```bash
node Machinery/cockpit/dashboard_server.js        # → http://127.0.0.1:8003/dashboard.html
```

(cf. `spec G1 — Cockpit/dashboard` et `S-10 | Cockpit` dans `state/architecture.md`.)
