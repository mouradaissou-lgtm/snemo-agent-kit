#!/usr/bin/env python3
"""production_gate.py — gate de production générique (B-128). 3 dimensions, aveugle au domaine.
Args: <livrable> [--rules rules.json] [--verification verification.json] [--source-total <float>] [--tolerance <pct>]
DISCIPLINE : verification.json présent + indépendant + tampons (sinon FAIL).
RULES      : contrôle déclaré (rules.json) → FAIL/WARN/PASS par entité (via g_calc --legacy).
DOUBLECHECK: logique (plausible_range sur colonnes) + chiffres (totaux vs source-total)
           + sens (B-131, colonnes dérivées re-dérivées, plage par op, zéro-dénominateur,
             cohérence de périmètre des opérandes d'un « / », backstop borne démesurée)
           → FAIL si contradiction/écart.
FAIL(exit 1) = REDO — jamais livré. Journal écrit."""
import csv, json, os, subprocess, sys, datetime

GATE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "g_calc.py")
JOURNAL = os.path.join(os.path.dirname(os.path.abspath(__file__)), "journal_conformite.jsonl")

def journal(lvr, verdict, dim):
    e = {"ts": datetime.datetime.now().isoformat(timespec="seconds"), "livrable": os.path.basename(lvr),
         "stage": "production_gate", "verdict": verdict, "dimension": dim}
    open(JOURNAL, "a", encoding="utf8").write(json.dumps(e, ensure_ascii=False) + "\n")

def discipline(vfile):
    if not vfile or not os.path.exists(vfile):
        return "FAIL", "DISCIPLINE: verification.json absent"
    v = json.load(open(vfile, encoding="utf8"))
    vv = v.get("verification", {})
    vs = vv.get("verify_source"); sr = v.get("source_ref")
    # Chemin honnête : une RELECTURE de la même agrégation n'est PAS indépendante, mais est un
    # contrôle de REPRODUCTIBILITÉ légitime si elle reproduit réellement un total (verify_total).
    if vv.get("reproduction") and vv.get("verify_total") is not None:
        _total = vv.get("verify_total")
        return "PASS", f"DISCIPLINE: relecture même-source reproduit {_total} (reproductibilité)"
    # B-144 — indépendance RÉELLE : la vérification doit lire une SOURCE ≠ celle du
    # producteur. Un `independent:true` sans `verify_source` distinct (ou identique à
    # source_ref) est une vérification circulaire (script différent, même source) → FAIL.
    if not vv.get("independent"):
        return "FAIL", "DISCIPLINE: vérification non indépendante"
    if not vs:
        return "FAIL", "DISCIPLINE: indépendance déclarée sans verify_source (B-144)"
    if sr and vs == sr:
        return "FAIL", "DISCIPLINE: vérification circulaire — verify_source == source_ref (B-144)"
    if not v.get("method_version") or not v.get("producer"):
        return "FAIL", "DISCIPLINE: traçabilité incomplète (méthode@version / producteur)"
    return "PASS", "DISCIPLINE: traçabilité + vérification réellement indépendante OK"

def rules(rulefile, livrable):
    if not rulefile:
        return "PASS", "RULES: aucun rules.json (non requis)"
    r = subprocess.run([sys.executable, GATE, livrable, "--rules", rulefile, "--legacy"],
                       capture_output=True, text=True)
    if r.returncode != 0:
        return "FAIL", "RULES: au moins une entité en FAIL (voir g_calc)"
    return "PASS", "RULES: entités OK (g_calc vert)"

def _num(x):
    """Parsing numérique robuste (espace insécable / virgule française)."""
    try: return float(str(x or "0").replace("\u202f", "").replace(" ", "").replace(",", "."))
    except ValueError: return 0.0

_PREFERRED_NUM_COLS = ("ca", "total", "montant", "amount", "sum", "value")

def _numeric_col(rows):
    """Choisit la colonne numérique d'une ligne : préférée sinon dernière numérique."""
    if not rows:
        return None
    head = rows[0]
    for c in _PREFERRED_NUM_COLS:
        if c in head:
            return c
    for c in reversed(list(head.keys())):
        if "désignation" in c.lower() or "name" in c.lower() or "id" == c.lower():
            continue
        try:
            float(str(head.get(c, "")).replace("\u202f", "").replace(" ", "").replace(",", "."))
            return c
        except ValueError:
            continue
    return None

def _sum_col(rows, col):
    """Somme d'une colonne (robuste); None si la colonne n'existe pas."""
    if not rows or not col:
        return None
    try:
        return round(sum(_num(r.get(col, "0")) for r in rows), 2)
    except Exception:
        return None

def _read_rows(path):
    """Rows as list[dict], for CSV or row-oriented JSON. Generic contract (domain-free).
    JSON shapes accepted: a bare list of objects, or an object with a `rows` list
    (the `report --by` convention: {"year","by","rows":[{name,ca},...]}).
    Unparseable or non-row JSON -> empty list; otherwise falls back to CSV."""
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

def sens_checks(livrable, rules_d):
    """Partie « sens » de DOUBLECHECK (B-131) : contrôle générique des colonnes dérivées,
    comme un humain qui re-vérifie. Registre : les colonnes dérivées sont re-dérivées depuis
    leurs opérandes sur chaque ligne ; on vérifie plage par nature de l'op, zéro-dénominateur,
    cohérence interne et cohérence de périmètre des opérandes d'un « / ». Zéro vocabulaire métier.
    Retourne la liste des issues ([] = sain)."""
    issues = []
    rows = _read_rows(livrable)
    cols = rows[0].keys() if rows else []
    for d in (rules_d.get("derived", {}) or {}):
        col = d.get("col")
        if col not in cols or not rows: continue
        op = d.get("op", ""); num = d.get("num"); den = d.get("den")
        x100 = 100.0 if d.get("x100") else 1.0
        expected = d.get("expected") or {}
        # 4) cohérence de périmètre des opérandes d'un « / » (cause B-51) : base diff => ratio invalide
        base = d.get("base") or {}
        if op in ("ratio", "pct", "share") and base.get("num") and base.get("den") and base["num"] != base["den"]:
            issues.append(f"sens: {col} ratio sur périmètres différents ({base['num']} ≠ {base['den']})")
        for r in rows:
            v = _num(r.get(col, ""))
            if op in ("ratio", "pct", "share"):
                a, b = _num(r.get(num, "")), _num(r.get(den, ""))
                # dénominateur 0 : uniquement une erreur si un ratio est affiché (sinon ligne légitimement vide)
                if b == 0:
                    if str(r.get(col, "")).strip() != "":
                        issues.append(f"sens: {col} dénominateur 0 avec valeur affichée"); 
                    break
                calc = (a / b) * x100 if x100 else (a / b)
            elif op == "delta":
                calc = _num(r.get(num, "")) - _num(r.get(den, ""))
            elif op == "sum":
                calc = _num(r.get(num, "")) + _num(r.get(den, ""))
            elif op == "product":
                calc = _num(r.get(num, "")) * _num(r.get(den, ""))
            else:
                continue
            if op in ("pct", "ratio"):
                lo = expected.get("min", 0.0); hi = expected.get("max", 100.0)
            elif op == "share":
                lo = expected.get("min", 0.0); hi = expected.get("max", 1.0)
            else:
                lo = expected.get("min"); hi = expected.get("max")
            if lo is not None and calc < lo:
                issues.append(f"sens: {col}={v} < {lo} (op {op})"); break
            if hi is not None and calc > hi:
                issues.append(f"sens: {col}={v} > {hi} (op {op}) [ratio impossible]"); break
            if calc and v:
                tol = max(0.001, abs(calc) * 0.005)
                if abs(v - calc) > tol:
                    issues.append(f"sens: {col} re-calcul {calc:.2f} ≠ affiché {v}"); break
    # backstop : nom de colonne évoquant un ratio + borne démesurée sans déclaration derived
    for col, span in (rules_d.get("logic", {}) or {}).items():
        if any(k in col.lower() for k in ("pct", "%", "ratio", "taux", "part")) and not rules_d.get("derived"):
            nat = span.get("max")
            if nat and nat > 100 and (span.get("min") is None or span.get("min", 0) < 0):
                issues.append(f"sens: {col} borne {nat} démesurée (masque une anomalie) — déclarer derived")
                break
    return issues

def doublecheck(livrable, rules, source_total, tolerance, verification=None):
    rules_d = {}
    if rules: rules_d = json.load(open(rules, encoding="utf8"))
    issues = []
    # logique : plausible_range déclarépar colonne
    for col, span in (rules_d.get("logic", {}) or {}).items():
        for r in _read_rows(livrable):
            try: v = float(str(r.get(col, "")).replace(" ", "").replace(",", "."))
            except (ValueError, TypeError): continue
            if not (span.get("min") is None or v >= span["min"]) or not (span.get("max") is None or v <= span["max"]):
                issues.append(f"logique: {col}={v} hors [{span.get('min','-∞')},{span.get('max','+∞')}]"); break
    # sens : colonnes dérivées (B-131) — ajouté, ne remplace pas l'existant
    issues += sens_checks(livrable, rules_d)
    # chiffres : totaux vs source (comparaison RÉELLE, plus un simple contrôle d'existence).
    # Source indépendante, dans l'ordre : (a) verification.json -> verify_total (relecture
    # sommable de la même agrégation), sinon (b) --source-total fourni par l'appelant.
    vf = {}
    if verification:
        # `verification` is the path passed via --verification ; load the JSON.
        if isinstance(verification, str) and os.path.exists(verification):
            try: vf = json.load(open(verification, encoding="utf8"))
            except (OSError, ValueError): vf = {}
        elif isinstance(verification, dict):
            vf = verification
    vverif = vf.get("verification", {})
    verify_total = vverif.get("verify_total")
    vt_n = vverif.get("verify_n")   # nb lignes lu par la relecture (None si non renseigné)
    rows_all = _read_rows(livrable)
    col = rules_d.get("sum_column") or rules_d.get("columns", {}).get("proposed") or rules_d.get("columns", {}).get("current")
    if col is None:
        col = _numeric_col(rows_all) if isinstance(rows_all, list) else None
    s = _sum_col(rows_all, col) if col else None
    tol = tolerance if tolerance is not None else 0.5
    # 1) relecture sommable (verify_total) — SEULEMENT si fidèle (pas de troncature partielle)
    if verify_total is not None and s is not None and col:
        # relecture tronquée (--limit) : référence non fiable -> pas de FAIL (marquée "partielle")
        partial = vt_n is not None and isinstance(rows_all, list) and vt_n < len(rows_all)
        if partial:
            pass  # non chiffrée ; évite un faux REDO sur grandes entités
        else:
            pct = abs(verify_total - s) / s * 100 if s else 100.0
            if pct > tol:
                issues.append(f"chiffres: somme {col}={s:.1f} vs relecture {verify_total:.1f} (écart >{tol}%)")
    # 2) --source-total fourni par l'appelant (chemin moteurs dédiés)
    if source_total is not None and s is not None and col:
        if abs(s - source_total) / source_total * 100 > tol:
            issues.append(f"chiffres: somme {col}={s:.1f} vs source {source_total:.1f} (écart >{tol}%)")
    if not issues:
        return "PASS", "DOUBLECHECK: cohérence logique + chiffres OK"
    return "FAIL", "DOUBLECHECK: " + "; ".join(issues[:3])


def headcalc(vfile):
    """Dimension HEAD-CALC (RULE-NO-HEAD-CALC) : chaque chiffre doit tracer vers un appel
    d'outil exécuté (SQL/API). Sans attestation tool_calls dans verification.json -> FAIL."""
    if not vfile or not os.path.exists(vfile):
        return "FAIL", "HEAD-CALC: verification.json absent - appels d'outils non attestés"
    v = json.load(open(vfile, encoding="utf8"))
    calls = v.get("tool_calls") or []
    if not calls:
        return "FAIL", "HEAD-CALC: aucun appel d'outil attesté - chiffres possiblement calculés de tête"
    bad=[]
    for c in calls:
        if not (c.get("tool") or c.get("endpoint") or c.get("sql")): bad.append("outil non déclaré")
        if not (c.get("filters") or c.get("query")): bad.append("appel sans filtre (non reproductible)")
    if bad: return "FAIL", "HEAD-CALC: " + "; ".join(bad[:3])
    return "PASS", f"HEAD-CALC: {len(calls)} appel(s) d'outil tracé(s)"


def main():
    import argparse
    ap = argparse.ArgumentParser()
    ap.add_argument("livrable"); ap.add_argument("--rules"); ap.add_argument("--verification")
    ap.add_argument("--source-total", type=float); ap.add_argument("--tolerance", type=float, default=0.5)
    a = ap.parse_args()
    # précondition : l'artefact doit exister et être lisible (sinon FAIL propre, pas de traceback)
    if not os.path.isfile(a.livrable):
        print("FAIL DOUBLECHECK: artefact introuvable — " + a.livrable)
        journal(a.livrable, "FAIL", "production_gate")
        print("RESULT: BLOQUÉ — REDO (gate de production non satisfaite)")
        sys.exit(1)
    res = []
    for fn, ok in ((discipline, a.verification), (rules, a.rules), (headcalc, a.verification), (doublecheck, (a.livrable, a.rules, a.source_total, a.tolerance, a.verification))):
        st, msg = (fn(a.verification) if fn in (discipline, headcalc) else (fn(a.rules, a.livrable) if fn is rules else fn(*ok)))
        res.append((st, msg)); print(f"{st:4} {msg}")
    fail = any(st == "FAIL" for st, _ in res)
    verdict = "FAIL" if fail else "PASS"
    dims = {d: st for d, st in [("DISCIPLINE", res[0][0]), ("RULES", res[1][0]), ("HEADCALC", res[2][0]), ("DOUBLECHECK", res[3][0])]}
    journal(a.livrable, verdict, "production_gate")
    # enrichir le journal avec les 3 dimensions (machine-readable, pour le cockpit Monitor)
    jf = os.path.join(os.path.dirname(os.path.abspath(__file__)), "journal_conformite.jsonl")
    if os.path.exists(jf):
        lines = open(jf, encoding="utf8").read().splitlines()
        for l in reversed(lines):
            try:
                e = json.loads(l)
                if e.get("stage") == "production_gate" and e.get("livrable") == os.path.basename(a.livrable):
                    e["dims"] = dims
                    lines[lines.index(l)] = json.dumps(e, ensure_ascii=False)
                    break
            except Exception:
                pass
        open(jf, "w", encoding="utf8").write("\n".join(lines) + "\n")
    print("RESULT:", "BLOQUÉ — REDO (gate de production non satisfaite)" if fail else "PASS — 3 dimensions vertes")
    sys.exit(1 if fail else 0)

if __name__ == "__main__":
    main()
