#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Registre de livrables (instance) : lit manifest.json, régénère index.html + zip.
Le dossier des livrables est résolu depuis ce fichier (<instance>/deliverables), surchargé
par DELIVERABLES_DIR. Usage : python3 update_deliverables_index.py [--serve-ok]
Aucun domaine.
"""
import json
import os
import sys
import zipfile

_HERE = os.path.dirname(os.path.abspath(__file__))
DELIVERABLES = os.environ.get("DELIVERABLES_DIR") or os.path.abspath(os.path.join(_HERE, "..", "..", "deliverables"))
MANIFEST = os.path.join(DELIVERABLES, "manifest.json")
INDEX = os.path.join(DELIVERABLES, "index.html")
ZIPNAME = "tous-les-rapports.zip"
ZIP = os.path.join(DELIVERABLES, ZIPNAME)
BASE = os.environ.get("DELIVERABLES_BASE", "http://127.0.0.1:8090")

CSS = """
:root{--bg:#f4f6fb;--card:#fff;--ink:#1f2937;--muted:#6b7280;--border:#e5e7eb;--blue:#2563eb;--green:#16a34a;--amber:#d97706}
*{box-sizing:border-box}
body{margin:0;font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,Helvetica,Arial,sans-serif;background:var(--bg);color:var(--ink);line-height:1.5;padding:24px}
.wrap{max-width:1000px;margin:0 auto}
h1{font-size:24px;margin:0 0 4px}
.sub{color:var(--muted);font-size:14px;margin-bottom:18px}
.card{background:var(--card);border:1px solid var(--border);border-radius:14px;padding:20px 22px}
table{width:100%;border-collapse:collapse;font-size:13.5px}
th,td{padding:8px;border-bottom:1px solid var(--border);text-align:left;vertical-align:top}
th{color:var(--muted);font-weight:600;font-size:11px;text-transform:uppercase;letter-spacing:.03em}
td.num{white-space:nowrap}
a{color:var(--blue);text-decoration:none}
a:hover{text-decoration:underline}
.badge{font-size:12px;font-weight:600;white-space:nowrap}
.b-saved{color:var(--green)}.b-prop{color:var(--amber)}
.meta{color:var(--muted);font-size:12.5px;margin-top:14px}
"""


def load_manifest():
    if not os.path.exists(MANIFEST):
        print("ERR: manifest.json absent", file=sys.stderr)
        sys.exit(2)
    with open(MANIFEST, encoding="utf-8") as f:
        return json.load(f)


def main():
    items = load_manifest()
    title = os.environ.get("DELIVERABLES_TITLE", "Livrables — catalogue")

    # 1) zip de TOUS les fichiers du dossier (rapports + assets), hors index/manifest/zip
    made = 0
    with zipfile.ZipFile(ZIP, "w", zipfile.ZIP_DEFLATED) as z:
        for fn in sorted(os.listdir(DELIVERABLES)):
            if fn in ("index.html", "manifest.json", ZIPNAME):
                continue
            p = os.path.join(DELIVERABLES, fn)
            if os.path.isfile(p):
                z.write(p, arcname=fn)
                made += 1

    # 2) index.html
    rows = []
    order = {"enregistré": 0, "proposé": 1, "écarté": 2}
    for it in sorted(items, key=lambda x: (order.get(x.get("statut", "proposé"), 9), x.get("date", ""), x.get("fichier") or x.get("url") or x.get("titre", ""))):
        st = it.get("statut", "proposé")
        badge = f'<span class="badge b-saved">🟢 enregistré</span>' if st == "enregistré" else (
            f'<span class="badge b-prop">🟠 proposé</span>' if st == "proposé" else f'<span class="badge">⚪ {st}</span>')
        if it.get("url"):
            rows.append(
                f'<tr><td class="num">🔗 <a href="{it["url"]}" target="_blank" rel="noopener">lien</a></td>'
                f'<td>{it.get("titre", "")}</td><td class="num">{it.get("date", "")}</td><td>{badge}</td>'
                f'<td class="num">—</td></tr>'
            )
            continue
        rows.append(
            f'<tr><td class="num"><a href="{BASE}/{it["fichier"]}">{it["fichier"]}</a></td>'
            f'<td>{it.get("titre", "")}</td><td class="num">{it.get("date", "")}</td><td>{badge}</td>'
            f'<td class="num">—</td></tr>'
        )
    n_saved = sum(1 for it in items if it.get("statut") == "enregistré")
    n_prop = sum(1 for it in items if it.get("statut") == "proposé")
    html = f"""<!DOCTYPE html>
<html lang="fr"><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>{title}</title><style>{CSS}</style></head>
<body><div class="wrap">
<h1>📎 {title}</h1>
<div class="sub">{len(items)} rapports au registre · {n_saved} enregistrés · {n_prop} proposés · liens cliquables (serveur local {BASE})</div>
<div class="card">
<table>
<tr><th>Fichier</th><th>Titre</th><th>Date</th><th>Statut</th></tr>
{''.join(rows)}
</table>
</div>
<p class="meta">Régénéré par <code>Machinery/07_reports/update_deliverables_index.py</code> · serveur local uniquement.</p>
</div></body></html>"""
    with open(INDEX, "w", encoding="utf-8") as f:
        f.write(html)

    print(f"OK index.html ({len(html)} o) + {ZIPNAME} ({made} fichiers zippés) | {n_saved} enregistrés / {n_prop} proposés / {len(items)} total")


if __name__ == "__main__":
    main()
