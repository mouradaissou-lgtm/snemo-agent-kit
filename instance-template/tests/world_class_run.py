#!/usr/bin/env python3
"""world_class_run.py — runner générique du World-Class Test (G9).

Lit `tests/world_class_test.json` et rapporte le verdict par couche et par cycle.

Schéma (celui de la donnée réelle) :
  {
    "nom": "World-Class Test", "version": "1.0", "status": "SKELETON"|"EN COURS"|"...",
    "total_testes": <int>,
    "couche_titres": {"1": "...", "2": "...", "3": "..."},
    "cycles": {
       "<cycle-id>": {"name": "<nom du cycle>",
                      "couches": {"1": {"n": <int>, "items": [<str|{nom,status}>]}, "2": {...}, "3": {...}}}
    },
    "manquants": [{"groupe": "...", "nom": "...", "detail": "..."}]
  }

Robuste : accepte aussi une forme plate (`couches` en dict de listes) et des items en chaîne
(déclarés, sans statut) ou en objet (`{"nom":..., "status": "pass|fail|todo"}`).
Un squelette vide n'est PAS un échec : il est rapporté « NOT GROUNDED » (honnête), jamais « pass ».
Aucun domaine.

Usage:
  python3 tests/world_class_run.py [--json] [--file tests/world_class_test.json]
Exit 0 = aucun item en échec ; 1 = au moins un FAIL.
"""
import argparse, json, os, sys

HERE = os.path.dirname(os.path.abspath(__file__))
DEFAULT = os.path.join(HERE, "world_class_test.json")

FAIL_STATES = {"fail", "failed", "ko", "echec", "échec"}
PASS_STATES = {"pass", "passed", "ok", "covered", "sain"}


def norm(s):
    return str(s or "").strip().lower()


def items_of(info):
    """Return the list of items for a layer entry ({"n","items"} | list | int)."""
    if isinstance(info, dict):
        it = info.get("items")
        return it if isinstance(it, list) else ([] if it is None else [it])
    if isinstance(info, list):
        return info
    return []


def walk(doc):
    """Yield (cycle_id, layer, item) over both the real (cycles→couches) and flat (couches) shapes."""
    cycles = doc.get("cycles") or {}
    if isinstance(cycles, dict):
        for cid, cyc in cycles.items():
            couches = (cyc or {}).get("couches") if isinstance(cyc, dict) else None
            if couches:
                for layer, info in couches.items():
                    for it in items_of(info):
                        yield cid, str(layer), it
            elif isinstance(cyc, list):            # cycles: {id: [items]}
                for it in cyc:
                    yield cid, None, it
    elif isinstance(cycles, list):
        for i, cyc in enumerate(cycles, 1):
            cid = (cyc or {}).get("id", i) if isinstance(cyc, dict) else i
            couches = (cyc or {}).get("couches", {}) if isinstance(cyc, dict) else {}
            for layer, info in (couches or {}).items():
                for it in items_of(info):
                    yield cid, str(layer), it
    # flat shape: top-level couches
    for layer, info in (doc.get("couches") or {}).items():
        for it in items_of(info):
            yield None, str(layer), it


def item_name(it):
    if isinstance(it, dict):
        return it.get("nom") or it.get("name") or it.get("id") or "?"
    return str(it)


def item_status(it):
    return norm(it.get("status")) if isinstance(it, dict) else ""


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--file", default=DEFAULT)
    ap.add_argument("--json", action="store_true")
    a = ap.parse_args()

    if not os.path.exists(a.file):
        print(f"ERR: {a.file} introuvable", file=sys.stderr); return 2
    doc = json.load(open(a.file, encoding="utf8"))

    per_layer, per_cycle = {}, {}
    total = fails = statused = 0
    names_fail = []
    for cid, layer, it in walk(doc):
        total += 1
        st = item_status(it)
        if st:
            statused += 1
        bucket = "fail" if st in FAIL_STATES else ("pass" if st in PASS_STATES else "declared")
        if bucket == "fail":
            fails += 1; names_fail.append(f"{cid or '-'}/{layer or '-'}:{item_name(it)}")
        if layer:
            per_layer.setdefault(layer, {"declared": 0, "pass": 0, "fail": 0})[bucket] += 1
        if cid is not None:
            per_cycle.setdefault(cid, {"declared": 0, "pass": 0, "fail": 0})[bucket] += 1

    grounded = total > 0
    if not grounded:
        verdict = "NOT GROUNDED (skeleton)"
    elif fails:
        verdict = "FAIL"
    elif statused == 0:
        verdict = "DECLARED (items present, none statused yet)"
    else:
        verdict = "PASS"

    out = {
        "file": a.file, "status": doc.get("status"), "version": doc.get("version"),
        "declared_total": doc.get("total_testes", 0),
        "items_found": total, "items_statused": statused, "fails": fails,
        "grounded": grounded, "verdict": verdict,
        "per_layer": per_layer, "per_cycle": per_cycle,
        "couche_titres": doc.get("couche_titres", {}),
        "manquants": [m.get("nom") for m in (doc.get("manquants") or []) if isinstance(m, dict)],
    }
    if a.json:
        print(json.dumps(out, ensure_ascii=False, indent=2))
    else:
        print(f"=== World-Class Test — {verdict} ===")
        print(f"  items: {total} (declared {out['declared_total']}, statused {statused}) | fails: {fails}")
        for c, v in sorted(per_layer.items()):
            print(f"  couche {c}: déclarés={v['declared']} pass={v['pass']} fail={v['fail']}")
        for c, v in sorted(per_cycle.items(), key=lambda kv: str(kv[0])):
            print(f"  cycle {c}: déclarés={v['declared']} pass={v['pass']} fail={v['fail']}")
        if out["manquants"]:
            print(f"  manquants ({len(out['manquants'])}): {', '.join(out['manquants'][:6])}")
        if not grounded:
            print("  (squelette vide — grounder les cycles/couches de l'instance en Phase 3-6)")
    return 1 if fails else 0


if __name__ == "__main__":
    sys.exit(main())
