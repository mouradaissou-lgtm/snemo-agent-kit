#!/usr/bin/env python3
"""monitor.py — backend du cockpit 'Monitor' d'une instance standalone : états du loop par
livrable & gate + la couverture spec / santé de l'instance.

Générique, aucun domaine. Le chemin de l'instance est résolu depuis ce fichier
(<instance>/Machinery/cockpit/monitor.py), surchargé par la variable d'environnement
DSH_INSTANCE_DIR. Lit le journal de conformité de l'instance (06_gates/journal_conformite.jsonl)
+ les livrables, puis enrichit le JSON avec un bloc `coverage` : core_check (G6 santé
universelle), et la matrice de couverture (tests/spec_coverage.json).

Sortie JSON : {
  livrables:[{livrable, stage, verdict, dims, ts}],
  summary:{production_gate_pass, delivery_pass, provenance_pass, total},
  coverage:{core_check:{...}, matrix:{...}}
}
Fail-soft : si un sous-outil échoue, le bloc `coverage` porte {"error":...} et le reste du
JSON continue de marcher — jamais de crash du cockpit.
"""
import json, os, sys, glob, subprocess, re

# RACINE de l'instance : <instance>/Machinery/cockpit/monitor.py -> <instance>/Machinery -> <instance>
_HERE = os.path.dirname(os.path.abspath(__file__))
INSTANCE = os.environ.get("DSH_INSTANCE_DIR") or os.path.abspath(os.path.join(_HERE, "..", ".."))
JOURNAL = os.path.join(INSTANCE, "06_gates", "journal_conformite.jsonl")
CORE_CHECK = os.path.join(INSTANCE, "core_check.sh")
SPEC_COV = os.path.join(INSTANCE, "tests", "spec_coverage.json")
# spec_check.sh vit dans le générateur (pas dans l'instance) ; signalé via env, sinon désactivé.
GEN_SPEC_CHECK = os.environ.get("DSH_SPEC_CHECK", "")


def _parse_json_line(line):
    """Renvoie dict si la ligne est un JSON valide, sinon None."""
    line = line.strip()
    if not (line.startswith("{") and line.endswith("}")):
        return None
    try:
        return json.loads(line)
    except ValueError:
        return None


def _run_json(cmd, cwd=None):
    """Exécute une commande, retourne dict JSON ou {"error":...} en cas d'échec (fail-soft)."""
    try:
        p = subprocess.run(cmd, capture_output=True, text=True, timeout=25, cwd=cwd)
        # Repli 1 : ligne JSON valide (stdout OU stderr, dernière d'abord).
        for stream in (p.stdout, p.stderr):
            for line in reversed(stream.splitlines()):
                d = _parse_json_line(line)
                if d is not None:
                    return d
        # Repli 2 : core_check --json émet parfois un JSON INVALIDE (la chaîne de "fails"
        # embarque un " brut -> JSON cassé). On extrait les compteurs par regex pour rester lisible.
        text = p.stdout + p.stderr
        m = re.search(r'"pass":(\d+),"fail":(\d+),"na":(\d+),"healthy":(true|false)', text)
        if m:
            return {"pass": int(m.group(1)), "fail": int(m.group(2)),
                    "na": int(m.group(3)), "healthy": m.group(4) == "true",
                    "note": "parsed", "fail_count": int(m.group(2))}
        return {"error": text.strip()[:200] or f"exit {p.returncode}"}
    except Exception as e:
        return {"error": str(e)}


def coverage_block():
    cov = {}
    # 1. spec_check (cohérence du spec) — seulement si le chemin est fourni (générateur).
    if GEN_SPEC_CHECK and os.path.exists(GEN_SPEC_CHECK):
        cov["spec_check"] = _run_json(["bash", GEN_SPEC_CHECK, "--json"])
    else:
        cov["spec_check"] = {"error": f"DSH_SPEC_CHECK non fourni/absent (generator-level): {GEN_SPEC_CHECK}"}
    # 2. core_check (G6 santé) — résout ROOT via pwd, donc on l'exécute DEPUIS la racine de l'instance.
    if os.path.exists(CORE_CHECK):
        cov["core_check"] = _run_json(["bash", CORE_CHECK, "--json"], cwd=INSTANCE)
    else:
        cov["core_check"] = {"error": f"core_check absent: {CORE_CHECK}"}
    # 3. matrice de couverture
    if os.path.exists(SPEC_COV):
        try:
            cov["matrix"] = json.load(open(SPEC_COV, encoding="utf8"))
        except ValueError as e:
            cov["matrix"] = {"error": str(e)}
    else:
        cov["matrix"] = {"error": f"spec_coverage.json absent: {SPEC_COV}"}
    return cov


def main():
    out = {"instance": INSTANCE,
           "livrables": [],
           "summary": {"production_gate_pass": 0, "delivery_pass": 0, "provenance_pass": 0, "total": 0}}
    if os.path.exists(JOURNAL):
        seen = set()
        for line in open(JOURNAL, encoding="utf8"):
            line = line.strip()
            if not line:
                continue
            try:
                e = json.loads(line)
            except ValueError:
                continue
            lv = e.get("livrable", "?")
            key = (lv, e.get("stage"), e.get("ts"))
            if key in seen:
                continue
            seen.add(key)
            out["livrables"].append({
                "livrable": lv, "stage": e.get("stage"), "verdict": e.get("verdict"),
                "dims": e.get("dims"), "ts": e.get("ts"), "orphelins": e.get("orphelins"),
            })
            s = e.get("stage")
            if e.get("verdict") == "PASS":
                if s == "production_gate":
                    out["summary"]["production_gate_pass"] += 1
                elif s == "delivery":
                    out["summary"]["delivery_pass"] += 1
                elif s == "provenance":
                    out["summary"]["provenance_pass"] += 1
        out["summary"]["total"] = len(out["livrables"])
    # couverture spec + santé
    out["coverage"] = coverage_block()
    print(json.dumps(out, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
