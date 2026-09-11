#!/usr/bin/env python3
"""spec_tracker_server.py — serveur de suivi du test de l'agent (catalogue + checks live).

Générique, aucun domaine. Sert :
  GET /         -> spec_tracker.html (l'UI)
  GET /catalog  -> spec_catalog.json (une ligne par fonction du spec + statut)
  GET /status   -> checks LIVE : core_check (santé) + couverture dérivée du catalogue
  GET /dataset  -> spec_catalog.json frais (pour rafraîchir le statut si le fichier change)

Autonome (stdlib seulement). Ne touche à rien en écriture — il LIT et renvoie.
La racine de l'instance est résolue depuis ce fichier (<instance>/tests/…), surchargée par
DSH_INSTANCE_DIR ; le port par DSH_SPEC_PORT (défaut 8092).
"""
import json, os, subprocess, sys
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

ROOT = os.path.dirname(os.path.abspath(__file__))                 # tests/
INSTANCE = os.environ.get("DSH_INSTANCE_DIR") or os.path.abspath(os.path.join(ROOT, ".."))
CATALOG = os.path.join(INSTANCE, "tests", "spec_catalog.json")
CORE = os.path.join(INSTANCE, "core_check.sh")
PORT = int(os.environ.get("DSH_SPEC_PORT", "8092"))
HOST = "127.0.0.1"

STATUS_MAP = {"covered": "conform", "partial": "partiel", "todo": "todo",
              "absent": "absent", "manquant": "absent", "na": "na"}


def load_catalog():
    with open(CATALOG, encoding="utf8") as f:
        return json.load(f)


def derived_coverage(cat):
    counts = {"conform": 0, "partiel": 0, "todo": 0, "absent": 0, "na": 0}
    for fn in cat.get("functions", []):
        st = str(fn.get("status", "todo")).strip().lower()
        counts[STATUS_MAP.get(st, "todo")] += 1
    counts["total"] = len(cat.get("functions", []))
    return counts


def live_status():
    out = {"instance": INSTANCE}
    try:
        p = subprocess.run(["bash", CORE, "--json"], capture_output=True, text=True,
                           timeout=60, cwd=INSTANCE)
        line = (p.stdout or p.stderr).strip().splitlines()[-1] if (p.stdout or p.stderr) else ""
        out["core_check"] = json.loads(line) if line.startswith("{") else {"raw": line[:200]}
    except Exception as e:
        out["core_check"] = {"error": str(e)}
    try:
        cat = load_catalog()
        out["coverage"] = derived_coverage(cat)
    except Exception as e:
        out["coverage"] = {"error": str(e)}
    return out


class H(BaseHTTPRequestHandler):
    def _send(self, body, ctype="application/json"):
        b = body.encode("utf8") if isinstance(body, str) else body
        self.send_response(200)
        self.send_header("Content-Type", ctype + "; charset=utf-8")
        self.send_header("Content-Length", str(len(b)))
        self.end_headers()
        self.wfile.write(b)

    def do_GET(self):
        path = self.path.split("?", 1)[0]
        if path in ("/", "/spec_tracker.html"):
            f = os.path.join(ROOT, "spec_tracker.html")
            if os.path.exists(f):
                self._send(open(f, encoding="utf8").read(), "text/html"); return
            self._send("<h1>spec_tracker.html absente</h1>", "text/html"); return
        if path in ("/catalog", "/dataset"):
            try:
                self._send(open(CATALOG, encoding="utf8").read())
            except Exception as e:
                self._send(json.dumps({"error": str(e)})); return
            return
        if path == "/status":
            self._send(json.dumps(live_status(), ensure_ascii=False, indent=2)); return
        self.send_response(404); self.end_headers(); self.wfile.write(b"not found")

    def log_message(self, *a):
        pass


if __name__ == "__main__":
    print(f"Spec tracker (instance) sur http://{HOST}:{PORT}  (instance: {INSTANCE})")
    ThreadingHTTPServer((HOST, PORT), H).serve_forever()
