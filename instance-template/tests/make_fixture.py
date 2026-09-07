#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Construit des fixtures (transcripts jsonl plain + facts.md + drafts) pour test_gate.sh.
Les transcripts sont en .jsonl PLAIN (iter_events lit en clair si pas .zstd), inclus un
appel SOURCE (bash ... --read) -> valeurs dans la provenance. Aucun domaine : les vraies
valeurs sont synthétiques (ALPHA/BETA/GAMMA). Sortir le dir."""
import json, os, sys

D = sys.argv[1] if len(sys.argv) > 1 else "/tmp/gate_fixtures"
os.makedirs(D, exist_ok=True)

VN = lambda v: v  # valeur

def ev(t, data, seq, turn=None, time=1_000_000_000_000):
    e = {"type": t, "seq": seq}
    if time: e["time"] = time
    if turn is not None: data = dict(data); data["turn"] = turn
    e["data"] = data
    return json.dumps(e, ensure_ascii=False)

def source_cmd():
    # Generic data-source fetch (recognized by provenance_gate.is_source_call as a live source).
    return json.dumps({"command": 'curl -s "http://127.0.0.1:8000/api/data?dim=sample&year=2025"'},
                      ensure_ascii=False)

def source_result():
    return {"message": {"content": [{"type": "tool-result",
                "content": [{"type": "text",
                    "text": "ALPHA 995814280.43, BETA 589852996.04, GAMMA 483298380"}]}]}}

def write_session(path, turns):
    """turns: liste de dicts {tools:bool source, answer:str}"""
    lines = []
    seq = 1000
    for i, tr in enumerate(turns, 1):
        # turn/start
        lines.append(ev("turn/start", {"turn": i}, seq, time=None)); seq += 1
        lines.append(ev("user/message", {"content": [{"type": "text", "text": "question " + str(i)}],
                     "source": {"kind": "user", "rpcId": "fx-%d" % i}, "role": "user"}, seq, turn=None)); seq += 1
        if tr.get("source"):
            args = json.loads(source_cmd())
            lines.append(ev("tool/call", {"turn": i, "step": 1, "callId": "c%d" % i,
                                          "name": "bash", "arguments": args}, seq)); seq += 1
            lines.append(ev("tool/result", dict(source_result(), turn=i), seq)); seq += 1
        if tr.get("answer"):
            lines.append(ev("assistant/message", {"turn": i, "step": 1,
                "message": {"role": "assistant", "content": [{"type": "text", "text": tr["answer"]}],
                            "source": {"kind": "model"}, "id": "m%d" % i}}, seq)); seq += 1
        lines.append(ev("turn/end", {"turn": i}, seq)); seq += 1
    open(path, "w", encoding="utf-8").write("\n".join(lines) + "\n")

# Session live : source DANS CE tour
write_session(os.path.join(D, "t_live.jsonl"),
              [{"source": True, "answer": ""}])
# Session reuse : source au tour 1, tour 2 (courant) SANS source
write_session(os.path.join(D, "t_reuse.jsonl"),
              [{"source": True, "answer": "Réponse intermédiaire."},
               {"source": False, "answer": ""}])

# facts.md avec un fait CONFLICTUEL
facts = """# Facts test
| F-XXX | sujet | valeur | base | date | source | statut | supersedes | conflit | notes |
| F-900 | CA net ALPHA 2025 | 995814280.43 | base agrégée | 2025 | sample | validated | — | **conflit** vs item-net 1086840800 | |
"""
open(os.path.join(D, "facts.md"), "w", encoding="utf-8").write(facts)

# Drafts (answers)
d = {}
d["pos_live.md"] = "Le CA net ALPHA est 995814280.43 (base agrégée)."     # sourced this turn -> PASS
d["pos_derived.md"] = "Σ des deux premiers = 995814280.43 + 589852996.04 = 1585667276.47."  # derived from sourced -> PASS
d["neg_orphan.md"] = "La somme vaut 4820118685.0."                             # not sourced -> FAIL
d["neg_claim.md"] = "Source : GET /plan-achat/skus renvoie 9 SKUs."               # claim sans appel -> FAIL (P2)
d["neg_conflict.md"] = "CA ALPHA 995814280.43."                              # fait coniflictuel sans base exposée -> FAIL (strict-b145)
d["neg_reuse.md"] = "La valeur ALPHA est 995814280.43."                   # tour 2 sans source, reuse (avec --no-reuse) -> FAIL
for name, txt in d.items():
    open(os.path.join(D, name), "w", encoding="utf-8").write(txt)

print(D)
