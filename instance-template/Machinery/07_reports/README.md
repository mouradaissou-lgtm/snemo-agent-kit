# Reports / deliverable server — instance

> Sert + indexe + package les livrables (HTML/CSV) de l'instance. Aucun domaine.

- `serve_deliverables.py` — serveur statique (port via `DELIVERABLES_PORT`, défaut 8090 ;
  dossier via `DELIVERABLES_DIR`, défaut = `<instance>/deliverables`). Routes catalogue :
  `/`, `/reports`, `/catalogue`, `/liste`, `/workspace` → `index.html`.
- `serve_deliverables.sh` — relaie vers `serve_deliverables.py`.
- `update_deliverables_index.py` — lit `<instance>/deliverables/manifest.json` et régénère
  `index.html` + `tous-les-rapports.zip` (titre via `DELIVERABLES_TITLE`).
- `add_pdf_button.py` — injecte le bouton « ⬇ Imprimer / PDF » dans les rapports HTML (idempotent).

(cf. `spec G2 — Reports/deliverables`.)
