#!/usr/bin/env python3
"""g_livraison_verif.py <artefact> — verrou d'exécution de livraison par compteur d'étapes (B-132).

Un livrable ne sort que si TOUTES les étapes du Loop sont franches ET le dernier verdict
production_gate (antérieur à la livraison) est PASS. Sinon REFUS (REDO) — pas convention, verrou.

Vérifie, pour l'artefact donné (basename = clé du journal) :
  1. verification.json présent + indépendant (DISCIPLINE, hérité de g_calc_delivery).
  2. le dernier `production_gate` de cet artefact (par séquence, pas par heure) a un verdict PASS ;
  3. les 3 dimensions (DISCIPLINE/RULES/DOUBLECHECK) de ce dernier production_gate sont chacune PASS ;
  4. la livraison n'a pas eu lieu AVANT le gate PASS.
Explicitement REFUSE le cas B-48 : production_gate FAIL puis delivery PASS.
Exit 0 = livrable autorisé ; exit 2 = REFUS (REDO) ; exit 3 = non vérifiable.
Générique : compte des étapes, aucun domaine."""
import csv, json, os, sys, subprocess, datetime

JOURNAL = os.environ.get("GATE_JOURNAL") or os.path.join(os.path.dirname(os.path.abspath(__file__)), "journal_conformite.jsonl")
DIMS = ("DISCIPLINE", "RULES", "DOUBLECHECK")

def fail(msg):
    print("VERIF REFUS — " + msg)
    return 2

def main():
    art = sys.argv[1] if len(sys.argv) > 1 else None
    if not art:
        print("artefact requis"); return 2
    d = os.path.dirname(os.path.abspath(art)); base = os.path.basename(art)
    # Resolve the sidecar as <stem>_verification.json first, then fall back to the literal
    # "verification.json" (what run_calc.py writes). Tolerates both conventions so a suffixed
    # sidecar (script-produced) or a co-located one (run_calc-produced) both count.
    stem = base.rsplit(".", 1)[0]
    side = os.path.join(d, stem + "_verification.json")
    if not os.path.exists(side):
        side = os.path.join(d, "verification.json")
    # 1) DISCIPLINE : verification.json présent + indépendant
    if not os.path.exists(side):
        return fail(f"{base} sans verification.json (ni <stem>_verification.json) → refaire avec 'run_calc --verify'")
    v = json.load(open(side, encoding="utf8"))
    if not v.get("verification", {}).get("independent"):
        return fail(f"{base} vérification non indépendante → seconde voie ≠ producteur")
    # B-144 — indépendance RÉELLE : verify_source doit différer de source_ref.
    vs = v.get("verification", {}).get("verify_source"); sr = v.get("source_ref")
    if not vs:
        return fail(f"{base} indépendance déclarée sans verify_source (B-144) → refaire")
    if sr and vs == sr:
        return fail(f"{base} vérification circulaire — verify_source == source_ref (B-144) → refaire avec une autre source")
    # 1bis) LOOP WALKED (mécanique) : un livrable numérique DOIT avoir tracé les 8 étapes (looptrace) —
    #       preuve que l'agent est passé par le loop (GRASP→…→GATE→LEARN). Sans trace = loop non parcouru = REDO.
    lt = os.path.join(d, base + ".looptrace.json")
    if not os.path.exists(lt):
        lt = os.path.join(d, stem + ".looptrace.json")
    if not os.path.exists(lt):
        return fail(f"{base} : pas de looptrace (8 étapes) → l'agent n'a pas parcouru le loop → REDO (B-132)")
    vf = os.path.join(os.path.dirname(os.path.abspath(__file__)), "verify_loop.sh")
    r = subprocess.run(["bash", vf, lt, "--artifact", art], capture_output=True, text=True)
    if r.returncode != 0:
        return fail(f"{base} : loop non parcouru (verify_loop exit {r.returncode}) — {r.stdout.strip()[:140]}")
    # 2-4) compteur d'étapes : lire le journal de l'artefact
    if not os.path.exists(JOURNAL):
        return fail("journal absent — aucune preuve de passage du gate")
    entries = [json.loads(l) for l in open(JOURNAL, encoding="utf8") if l.strip()]
    gates = [e for e in entries if e.get("stage") == "production_gate" and e.get("livrable") == base]
    deliveries = [e for e in entries if e.get("stage") == "delivery" and e.get("livrable") == base]
    if not gates:
        return fail(f"{base} : aucune production_gate au journal — étape non franchie")
    # gate à considérer = le dernier production_gate de l'artefact (par séquence du journal)
    last_gate_idx = max((i for i, e in enumerate(entries)
                         if e.get("stage") == "production_gate" and e.get("livrable") == base), default=-1)
    if last_gate_idx < 0:
        return fail(f"{base} : gate non trouvé — étape non franchie")
    last = entries[last_gate_idx]
    if last.get("verdict") != "PASS":
        return fail(f"{base} : dernier production_gate = {last.get('verdict')} (RULES/DOUBLECHECK) → REDO (B-132)")
    dims = last.get("dims") or {}
    missing = [d for d in DIMS if dims.get(d) != "PASS"]
    if missing:
        return fail(f"{base} : dimension(s) non PASS au dernier gate : {', '.join(missing)} → REDO")
    # 4) ne pas livrer si un delivery PASS a été enregistré AVANT ce gate (ordre trompeur B-48)
    last_deliv_idx = max((i for i, e in enumerate(entries)
                          if e.get("stage") == "delivery" and e.get("livrable") == base), default=-1)
    if last_deliv_idx >= 0 and last_deliv_idx < last_gate_idx:
        return fail(f"{base} : livraison enregistrée AVANT le dernier gate PASS → re-livrer après gate")
    print(f"VERIF OK — {base} : toutes étapes franches, gate PASS (DISCIPLINE+RULES+DOUBLECHECK), verification indépendante.")
    return 0

if __name__ == "__main__":
    sys.exit(main())
