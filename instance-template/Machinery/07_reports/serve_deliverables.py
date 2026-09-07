#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Serveur statique des livrables (instance) — routes nommées vers le catalogue.

Sert le catalogue (index.html) sur /, /reports, /catalogue, /liste, /workspace ;
tous les autres chemins servent les fichiers du dossier livrables.
Bind explicite 127.0.0.1:8090. Le dossier des livrables est résolu depuis ce fichier
(<instance>/deliverables), surchargé par DELIVERABLES_DIR. Aucun domaine.
"""
import functools
import http.server
import os
from pathlib import Path

DELIVERABLES = Path(os.environ.get("DELIVERABLES_DIR") or
                    Path(__file__).resolve().parent.parent.parent / "deliverables")
PORT = int(os.environ.get("DELIVERABLES_PORT", "8090"))
HOST = "127.0.0.1"
CATALOGUE_ROUTES = {"/", "/reports", "/catalogue", "/liste", "/workspace"}


class DeliverablesHandler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=str(DELIVERABLES), **kwargs)

    def do_GET(self):
        path = self.path.split("?", 1)[0]
        if path in CATALOGUE_ROUTES:
            self.path = "/index.html"
        super().do_GET()

    def log_message(self, fmt, *args):
        pass  # silencieux (serveur local)


if __name__ == "__main__":
    server = functools.partial(http.server.ThreadingHTTPServer, (HOST, PORT), DeliverablesHandler)
    httpd = server()
    print(f"Livrables (instance) servis sur http://{HOST}:{PORT}  (dossier: {DELIVERABLES})")
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        pass
