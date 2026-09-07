#!/usr/bin/env python3
"""g_calc.py — LA gate de calcul (B-126). Une gate, deux layers.

Layer 1 — DISCIPLINE (toujours, universelle, aucun domaine) :
  traçabilité (méthode@version + producteur + référence source),
  enregistrement de vérification indépendante (méthode déclarée ≠ voie productrice, résultat),
  tampons (fraîcheur des données). Manquant → FAIL : pas de livraison.

Layer 2 — RÈGLES DÉCLARÉES (optionnel, si --rules) :
  les contrôles par ligne déclarés dans rules.json (complétude, tendance vs référence,
  variation, couverture, ratio extrême) → FAIL/WARN/PASS par entité.

Usage :
  g_calc.py <livrable.csv> --meta meta.json [--rules rules.json]   # full (layer 1 + 2)
  g_calc.py <livrable.csv> --rules rules.json --legacy             # compat sanity_gate (layer 2 seule, sémantique historique)

FAIL (exit 1) = pas de livraison — retour producteur (B-125)."""
import argparse, csv, json, os, sys, datetime

TRUTHY = {"1","true","oui","yes","complet"}

def num(v):
    return float(str(v).replace("\u202f","").replace(" ","").replace(",","."))

def _read_rows(path):
    """Rows as list[dict], for CSV or row-oriented JSON. Generic contract (domain-free).
    JSON shapes accepted: a bare list of objects, or an object with a `rows` list
    (the `report --by` convention). Unparseable or non-row JSON -> empty list;
    otherwise falls back to CSV."""
    if not os.path.exists(path) or not os.access(path, os.R_OK):
        return []
    try:
        data = json.load(open(path, encoding="utf8"))
    except (OSError, ValueError):
        return list(csv.DictReader(open(path, encoding="utf8")))
    if isinstance(data, list):
        return [r for r in data if isinstance(r, dict)]
    if isinstance(data, dict):
        return data["rows"] if isinstance(data.get("rows"), list) else []
    return []

def layer1(meta):
    fails=[]
    if not meta:
        return ["layer 1: aucun enregistrement de traçabilité/vérification (—meta requis)"]
    for k,lab in (("producer","producteur"),("method_version","méthode@version"),("source_ref","référence source")):
        if not str(meta.get(k,"")).strip(): fails.append(f"layer 1: {lab} manquant")
    v = meta.get("verification") or {}
    if not str(v.get("method","")).strip(): fails.append("layer 1: méthode de vérification manquante")
    if not v.get("independent"): fails.append("layer 1: vérification non indépendante (même voie que le producteur)")
    if not str(v.get("result","")).strip(): fails.append("layer 1: résultat de vérification manquant")
    if not str(meta.get("data_freshness","")).strip(): fails.append("layer 1: fraîcheur des données manquante")
    return fails

JOURNAL = os.path.join(os.path.dirname(os.path.abspath(__file__)), "journal_conformite.jsonl")

def journal(livrable, rules, verdict, nf, nw, lifting):
    entry = {"ts": datetime.datetime.now().isoformat(timespec="seconds"),
             "livrable": os.path.basename(str(livrable)),
             "rules": os.path.basename(str(rules)) if rules else None,
             "verdict": verdict, "fail": nf, "warn": nw,
             "lifting_condition": lifting if nw else None}
    with open(JOURNAL, "a", encoding="utf8") as fh:
        fh.write(json.dumps(entry, ensure_ascii=False) + "\n")

def layer2(rules, livrable, legacy):
    # Dispatch on the rules schema. Two shapes are in use across instances:
    #   * per-row calibration   : {"columns": {entity, proposed, current, window_current,
    #                               window_reference, complete}, ...}  (the target-calibration schema)
    #   * aggregate sanity      : {"sum_column": x, "logic": {col:{min,max}}, "derived": [...]}
    #                               (the production/prose-sens schema — GDBC's declared rules)
    # The old code did `col = rules["columns"]` unconditionally; an aggregate-style rules file
    # (GDBC's real files) KeyErrored. Dispatch so neither shape crashes.
    if "columns" in rules:
        return layer2_rows(rules, livrable, legacy)
    if "sum_column" in rules or "logic" in rules or "derived" in rules:
        return layer2_aggregate(rules, livrable)
    print("WARN: rules.json ne porte ni 'columns' (calibration par ligne) ni 'sum_column/logic/derived' (bornes agrégées) — layer 2 ignoré")
    return 0, 0


def layer2_aggregate(rules, livrable):
    """Aggregate-sanity layer 2 (GDBC's `sum_column`/`logic`/`derived` schema).

    `logic[col].min/.max` bounds and `derived[].expected` bounds are checked against each row's
    columns (the summary value lives in the single aggregated row, but we validate every row so a
    stray zero/negative/ratio>100% is caught). For the derived columns (e.g. `pct` = num/den*100),
    we re-derive the value and check it against its expected [min,max] — the production_gate sens
    contract. Returns (nf, nw).
    """
    def _num(v):
        try: return num(v)
        except Exception: return None
    rows = _read_rows(livrable)
    out = []; nf = 0; nw = 0
    logic = rules.get("logic") or {}
    derived = rules.get("derived") or []
    for r in rows:
        flags = []
        status = "PASS"
        # 1) direct bounds (logic)
        for col, span in logic.items():
            v = _num(r.get(col))
            if v is None: continue
            mn = span.get("min"); mx = span.get("max")
            if mn is not None and v < mn:
                status = "FAIL"; flags.append(f"{col}={v:g} < {mn:g} (borne min)")
            if mx is not None and v > mx:
                status = "FAIL"; flags.append(f"{col}={v:g} > {mx:g} (borne max)")
        # 2) derived columns (sens) — re-derive num/den, apply x100, check expected [min,max]
        for d in derived:
            nv = _num(r.get(d.get("num"))); dv = _num(r.get(d.get("den")))
            if nv is None or dv is None or dv == 0:
                flags.append(f"derivé {d.get('col')}: dénominateur 0 ou absents")  # sens: zéro-dénominateur
                if status != "FAIL": status = "WARN"
                continue
            val = (nv / dv) * (100 if d.get("x100") else 1)
            exp = d.get("expected") or {}
            mn = exp.get("min"); mx = exp.get("max")
            if mn is not None and val < mn:
                status = "FAIL"; flags.append(f"{d.get('col')}={val:.2f} < {mn:g}")
            if mx is not None and val > mx:
                status = "FAIL"; flags.append(f"{d.get('col')}={val:.2f} > {mx:g}")
        line = f"{status:4} {r.get('month', r.get('entity', '—') if isinstance(r, dict) else 'row')}: " \
               + "; ".join(f"{k}={r.get(k)}" for k in rules.get("logic", {})) if r else ""
        if flags: line += "  [" + " ; ".join(flags) + "]"
        out.append(line if line else json.dumps(r, ensure_ascii=False))
        if status == "FAIL": nf += 1
        elif status == "WARN": nw += 1
    print("\n".join(out))
    if nf: print(f"FAIL: {nf} ligne(s)")
    if nw: print(f"WARN: {nw} ligne(s)")
    return nf, nw


def layer2_rows(rules, livrable, legacy):
    col = rules["columns"]
    rows = _read_rows(livrable)
    out=[]; nf=0; nw=0
    for r in rows:
        e = r[col["entity"]]
        P = num(r[col["proposed"]]); C = num(r[col["current"]])
        wc = num(r[col["window_current"]]); wr = num(r[col["window_reference"]])
        complete = str(r[col["complete"]]).strip().lower() in TRUTHY
        flags = []
        mc = col.get("months_covered")
        if mc and mc in r and rules.get("min_months_covered"):
            try:
                cov,tot = str(r[mc]).split("/")
                if float(cov)/float(tot) < float(rules["min_months_covered"])/12:
                    complete = False
                    flags.append("couverture partielle → traité comme incomplet")
            except ValueError:
                complete = False
                flags.append("mois_couverts illisible → traité comme incomplet")
        var = (P-C)/C*100 if C else float("inf")
        declining = wc < wr
        increasing = P > C
        status = "PASS"
        if rules.get("declining_no_increase", True) and declining and increasing:
            status = "FAIL"; flags.append("augmentation sur entité en déclin")
        if rules.get("require_completeness", True) and not complete and increasing:
            if status != "FAIL": status = "WARN"
            flags.append("données incomplètes → proposition conditionnelle — condition de levée: compléter les données")
        sampled = abs(var) > rules.get("max_variation_pct", 15)
        if sampled:
            if legacy:
                if status != "FAIL": status = "WARN"
                flags.append(f"variation {var:+.1f}% > {rules['max_variation_pct']}% → escalade Tier 1")
            else:
                flags.append(f"variation {var:+.1f}% — échantillonnée Tier 1")
        if "outlier_ratio" in rules and wc and wr:
            ratio = wc / wr
            if ratio >= rules["outlier_ratio"] or ratio <= 1/rules["outlier_ratio"]:
                if status != "FAIL": status = "WARN"
                flags.append(f"choc structurel ou one-off (ratio ×{ratio:.2f}) — jugement requis")
        line = f"{status:4} {e}: {C:g} → {P:g} ({var:+.1f}%)"
        if flags: line += "  [" + " ; ".join(flags) + "]"
        out.append(line)
        if status=="FAIL": nf+=1
        elif status=="WARN": nw+=1
    print("\n".join(out))
    if nf: print(f"FAIL: {nf} entité(s)")
    if nw: print(f"WARN: {nw} entité(s)")
    return nf, nw

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("livrable", nargs="?")
    ap.add_argument("--meta")
    ap.add_argument("--rules")
    ap.add_argument("--legacy", action="store_true")
    ap.add_argument("--journal", nargs="?", const=20, default=None)
    a = ap.parse_args()
    if a.journal is not None:
        jf = JOURNAL
        if not os.path.exists(jf):
            print("journal vide (aucune exécution enregistrée)"); sys.exit(0)
        lines = open(jf, encoding="utf8").read().splitlines()
        n = int(a.journal)
        for l in lines[-n:]:
            e = json.loads(l)
            # tolérant aux formats de journal hétérogènes (g_calc layer2 / production_gate / delivery)
            print(f'{e.get("ts","?")}  {e.get("verdict","?"):4}  '
                  f'fail={e.get("fail","-")!s:<4} warn={e.get("warn","-")!s:<4}  '
                  f'{e.get("livrable","?")}'
                  + (f'  [{e["dimension"]}]' if e.get("dimension") else "")
                  + (f'  [{e["stage"]}]' if e.get("stage") and e.get("stage") != "production_gate" else ""))
        c = {}
        for l in lines:
            e = json.loads(l); c[e["verdict"]] = c.get(e["verdict"], 0) + 1
        print(f"--- {len(lines)} exécutions · " + " · ".join(f"{k}:{v}" for k,v in sorted(c.items())))
        sys.exit(0)
    if not a.livrable:
        ap.error("livrable requis")
    # précondition : l'artefact doit exister et être lisible (sinon FAIL propre, pas de traceback)
    if not os.path.isfile(a.livrable):
        print("FAIL: artefact introuvable — " + a.livrable)
        journal(a.livrable, a.rules, "FAIL", 1, 0, None)
        print("RESULT: BLOQUÉ — pas de livraison (retour producteur)")
        sys.exit(1)
    fails=[]
    nf=nw=0; verdict="PASS"; lifting=""
    if a.meta:
        meta = json.load(open(a.meta, encoding="utf8"))
        fails += layer1(meta)
    elif not a.legacy:
        fails.append("layer 1: aucun --meta fourni (traçabilité + vérification indépendante requises)")
    if a.rules:
        rules = json.load(open(a.rules, encoding="utf8"))
        nf, nw = layer2(rules, a.livrable, a.legacy)
        if nf: fails.append(f"layer 2: {nf} entité(s) en FAIL")
        if nw:
            lifting = "compléter les données / vérifications (voir flags)"
    verdict = "FAIL" if fails or nf else ("WARN" if nw else "PASS")
    journal(a.livrable, a.rules, verdict, nf, nw, lifting)
    for x in fails: print("FAIL", x)
    print("RESULT:", "BLOQUÉ — pas de livraison (retour producteur)" if fails else
          ("WARN — livrable conditionnel, flags en tête obligatoires" if nw else
           "PASS — livrable validé par la gate de calcul"))
    sys.exit(1 if fails else 0)

if __name__ == "__main__":
    main()
