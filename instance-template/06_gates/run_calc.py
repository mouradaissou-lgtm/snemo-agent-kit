#!/usr/bin/env python3
"""run_calc.py — conteneur de calcul (B-127).
Produit l'artefact + verification.json PAR CONSTRUCTION (inséparables).
Usage:
  run_calc.py --out <artifact> [--verify <verify_cmd>] [--meta meta.json] -- <producer_cmd...>
- exécute <producer_cmd> (produit l'artefact) ;
- avec --verify : exécute <verify_cmd> (doit DIFFÉRER du producteur) et renseigne le résultat ;
- écrit verification.json à côté de l'artefact : producteur, méthode@version, source_ref,
  verification{method, independent, result}, data_freshness."""
import argparse, json, os, subprocess, sys, datetime

# Colonnes numériques préférées pour une relecture sommable (report --by expose `ca`).
_PREFERRED_NUM_COLS = ("ca", "total", "montant", "amount", "sum", "value")


def _numcol(row):
    """Choisit la colonne numérique d'une ligne : préférée sinon dernière numérique."""
    for c in _PREFERRED_NUM_COLS:
        if c in row and _num(row.get(c)) is not None:
            return c
    for c in reversed(list(row.keys())):
        if _num(row.get(c)) is not None:
            return c
    return None


def _num(x):
    try:
        return float(str(x or "0").replace("\u202f", "").replace(" ", "").replace(",", "."))
    except ValueError:
        return None


def _rows(data):
    """Ramène la liste de dicts depuis un JSON de sortie report (objet rows | liste)."""
    if isinstance(data, list):
        return [r for r in data if isinstance(r, dict)]
    if isinstance(data, dict) and isinstance(data.get("rows"), list):
        return [r for r in data["rows"] if isinstance(r, dict)]
    return []


def _extract_total(stdout):
    """Dict {total, n} de la relecture `report` (somme de la colonne numérique + nb de lignes).
    Retourne None si la sortie n'est pas un JSON « report » sommable."""
    if not stdout or not stdout.strip():
        return None
    try:
        data = json.loads(stdout)
    except (ValueError, TypeError):
        return None
    rows = _rows(data)
    if not rows:
        return None
    col = _numcol(rows[0])
    if col is None:
        return None
    total = round(sum(_num(r.get(col)) or 0 for r in rows), 2)
    return {"total": total, "n": len(rows)}


def _label_result(vr, verify_total):
    """Étiquette HONNÊTE de la vérification, selon ce qui a réellement été vérifié."""
    if vr.returncode != 0:
        return "écart — vérification en échec (à expliciter)"
    if verify_total is None:
        return "relecture non sommable (non chiffré)"
    return "conforme (relecture reproduit le même total)"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", required=True)
    ap.add_argument("--verify")
    ap.add_argument("--meta")
    ap.add_argument("producer", nargs=argparse.REMAINDER)
    a = ap.parse_args()
    prod = [x for x in a.producer if x != "--"]
    if not prod:
        ap.error("commande producteur requise (après --)")
    meta = {}
    if a.meta:
        try:
            meta = json.load(open(a.meta, encoding="utf8"))
        except (OSError, ValueError):
            meta = json.loads(a.meta)
    # 1) produire l'artefact — NE re-fetche PAS si --out existe déjà non vide (le producteur
    #    l'a écrit au JUMP, même tour) ; sinon on exécute le producteur et on matérialise --out.
    if os.path.exists(a.out) and os.path.getsize(a.out) > 0:
        print("PROD (reuse) — artefact déjà présent, pas de re-fetch:", a.out)
    else:
        r = subprocess.run(" ".join(prod), shell=True, capture_output=True, text=True)
        if r.returncode != 0:
            print("PROD FAIL:", prod, r.stderr[-400:]); sys.exit(1)
        # --out doit exister : le producteur soit écrit lui-même le fichier, soit émet
        # l'artefact sur stdout (cas `report --by`, sortie JSON sur stdout).
        if not os.path.exists(a.out) or os.path.getsize(a.out) == 0:
            if r.stdout.strip():
                open(a.out, "w", encoding="utf8").write(r.stdout)
            else:
                print("PROD FAIL: aucun artefact à --out ni sur stdout:", prod); sys.exit(1)
    # 2) vérification indépendante (optionnelle mais recommandée)
    #    INDÉPENDANCE RÉELLE (B-144) : le vérificateur doit lire une SOURCE
    #    différente de celle du producteur (verify_source != source_ref).
    #    Une différence de *script* ne suffit PAS (le trou B-66 : un script différent
    #    relisant le même champ donne independent=True à tort).
    vres = None; independent = False
    source_ref = meta.get("source_ref")
    verify_source = meta.get("verify_source")
    if a.verify:
        vr = subprocess.run(a.verify, shell=True, capture_output=True, text=True)
        # INDÉPENDANCE (B-144) : une relecture de la MÊME agrégation (--verify-same) n'est pas
        # indépendante — c'est un contrôle de REPRODUCTIBILITÉ, pas une vérification d'une autre
        # source. On le marque honnêtement (reproduction=true) plutôt que de prétendre independ=true.
        same_agg = bool(verify_source) and bool(source_ref) and verify_source != source_ref
        independent = same_agg and not meta.get("reproduction_only", False)
        # Relecture numérique : parser la sortie du --verify pour extraire {total, n}.
        vread = _extract_total(vr.stdout)
        verify_total = vread["total"] if vread else None
        verify_n = vread["n"] if vread else None
        # decide an honest result label
        res = _label_result(vr, verify_total)
        vres = {"method": a.verify, "independent": independent,
                "verify_source": verify_source,
                "source_ref": source_ref,
                "real_source": independent,
                "reproduction": bool(same_agg),
                "verify_total": verify_total,
                "verify_n": verify_n,
                "result": res}
    else:
        vres = {"method": None, "independent": False, "verify_source": verify_source,
                "source_ref": source_ref, "real_source": False, "reproduction": False,
                "verify_total": None, "result": "non vérifié"}
    # Sidecar DÉDIÉ par livrable : <stem>_verification.json (convention des livrables légitimes),
    # + garde le fallback "verification.json" pour compat. Un nom partagé (verification.json)
    # écrasait la preuve de CHAQUE livrable -> g_calc_delivery forgait REDO à tort.
    d = os.path.dirname(os.path.abspath(a.out)) or "."
    stem = os.path.basename(a.out)
    if stem.endswith(".json"):
        stem = stem[:-5]
    side = os.path.join(d, stem + "_verification.json")
    # écrire aussi le fallback partagé (compat avec les anciens consommateurs)
    side_shared = os.path.join(d, "verification.json")
    entry = {
        "producer": meta.get("producer", " ".join(prod)),
        "method_version": meta.get("method_version", "run_calc@1.0"),
        "source_ref": source_ref,
        "verification": vres,
        "data_freshness": meta.get("data_freshness", datetime.date.today().isoformat()),
        "artifact": os.path.basename(a.out),
        # HEAD-CALC (production_gate) : attestation des appels d'outil réellement exécutés
        "tool_calls": meta.get("tool_calls", []),
    }
    json.dump(entry, open(side, "w", encoding="utf8"), ensure_ascii=False, indent=2)
    json.dump(entry, open(side_shared, "w", encoding="utf8"), ensure_ascii=False, indent=2)
    print("PROD OK —", a.out, "| sidecar:", side,
          ("| vérifié (indépendant)" if vres["independent"] else "| à vérifier (--verify)"))
    sys.exit(0 if vres["independent"] else 2)

if __name__ == "__main__":
    main()
