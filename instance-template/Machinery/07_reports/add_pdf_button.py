#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Injection du bouton « ⬇ Imprimer / PDF » dans les rapports HTML (impression/PDF).

Idempotent : marqueur data-pdf-btn ; ne ré-injecte jamais deux fois.
Ajoute : bouton flottant (window.print), @media print (masquage + fond blanc),
print-color-adjust, et support de ?print=1 (impression auto au chargement).
Le dossier des livrables est résolu depuis ce fichier (<instance>/deliverables),
surchargé par DELIVERABLES_DIR. Aucun domaine.
Usage : python3 add_pdf_button.py [--check]
"""
import os
import re
import sys

_HERE = os.path.dirname(os.path.abspath(__file__))
DELIVERABLES = os.environ.get("DELIVERABLES_DIR") or os.path.abspath(os.path.join(_HERE, "..", "..", "deliverables"))
MARKER = "data-pdf-btn"

BLOCK = """
<div class="pdf-btn" data-pdf-btn>
  <button type="button" onclick="window.print()" title="Télécharger en PDF (dialogue d'impression → Enregistrer au format PDF)">⬇ Imprimer / PDF</button>
</div>
<style>
.pdf-btn{position:fixed;top:14px;right:14px;z-index:9999;font-family:inherit}
.pdf-btn button{background:#2563eb;color:#fff;border:none;border-radius:8px;padding:9px 14px;font-size:13px;font-weight:600;cursor:pointer;box-shadow:0 2px 8px rgba(0,0,0,.25);font-family:inherit}
.pdf-btn button:hover{background:#1d4ed8}
@media print{.pdf-btn{display:none!important}}
@media print{body{background:#fff!important}}
*{-webkit-print-color-adjust:exact;print-color-adjust:exact}
</style>
<script>
(function(){if(location.search.indexOf('print=1')>-1){setTimeout(function(){window.print()},400)}})();
</script>
"""


def inject(path: str) -> str:
    with open(path, encoding="utf-8") as f:
        html = f.read()
    if MARKER in html:
        return "skip"
    if "</body>" not in html:
        return "no-body"
    html = html.replace("</body>", BLOCK + "\n</body>", 1)
    with open(path, "w", encoding="utf-8") as f:
        f.write(html)
    return "ok"


def main():
    check = "--check" in sys.argv
    total = ok = skipped = no_body = 0
    for fn in sorted(os.listdir(DELIVERABLES)):
        if not fn.endswith(".html"):
            continue
        path = os.path.join(DELIVERABLES, fn)
        total += 1
        status = inject(path) if not check else ("ok" if MARKER in open(path, encoding="utf-8").read() else "absent")
        if status == "ok":
            ok += 1
        elif status == "skip":
            skipped += 1
        else:
            no_body += 1
            print(f"WARN: {fn} -> {status}")
    print(f"{'Vérification' if check else 'Injection'} : {total} rapports | injectés/ok={ok} | déjà équipés={skipped} | problème={no_body}")


if __name__ == "__main__":
    main()
