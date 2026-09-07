#!/bin/bash
# Relance le serveur des livrables (instance) (routes /reports, /catalogue, /workspace…).
# Rituel : ./serve_deliverables.sh   (ou job d'arrière-plan du harness)
cd "$(dirname "$0")" && exec python3 serve_deliverables.py
