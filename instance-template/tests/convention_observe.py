#!/usr/bin/env python3
"""convention_observe.py — helpers de lecture transcript pour convention_generic.sh.

Lit le JSONL de session sur stdin (décompressé), filtre la fenêtre [start_ms, end_ms]
et imprime un JSON d'observation (user + tool calls classés). Usage (via pipe) :
    zstd -d -c session.jsonl.zstd | convention_observe.py wait_end <start_ms>
    zstd -d -c session.jsonl.zstd | convention_observe.py observe <start_ms> <end_ms> [verbose]
"""
import sys, json

def kind_of(name, args):
    if "ask_user_question" in name:
        return "ask"
    if "livrer.sh" in args:
        return "livrer"
    if "loop.sh" in args:
        return "loop"
    # Generic data-aggregate reader: any "<tool>_api.py report --by/--target" call. Aucun domaine :
    # on matche le sous-commande `report` + un argument d'agrégation, quel que soit l'outil.
    if "report" in args and ("--by" in args or "--target" in args or "--metric" in args):
        return "report"
    return "other"

def main():
    if len(sys.argv) < 3:
        print("usage: convention_observe.py wait_end <start_ms> | observe <start_ms> <end_ms> [verbose]", file=sys.stderr)
        return 2
    mode = sys.argv[1]
    start = int(sys.argv[2])
    end = int(sys.argv[3]) if mode == "observe" and len(sys.argv) > 3 else None
    verbose = (len(sys.argv) > 4 and sys.argv[4] == "1") or (mode == "wait_end")

    calls = []; user = None; done_last = 0
    for line in sys.stdin.buffer.read().decode("utf-8", "replace").splitlines():
        if not line.strip():
            continue
        try:
            e = json.loads(line)
        except Exception:
            continue
        t = e.get("type"); d = e.get("data") or {}; tm = e.get("time")
        if not isinstance(tm, (int, float)):
            continue
        if mode == "wait_end":
            if t == "turn/end" and tm > start and tm > done_last:
                done_last = int(tm)
            continue
        # observe mode
        if tm <= start or tm > end + 1:
            continue
        if t == "tool/call":
            nm = d.get("name", ""); args = str(d.get("arguments", ""))
            calls.append({"name": nm, "kind": kind_of(nm, args), "args": args[:160]})
        elif t == "user/message":
            src = (d.get("source") or {}).get("kind")
            if src == "plugin":
                continue
            txt = "".join(c.get("text", "") for c in d.get("content", []) if isinstance(c, dict))
            if txt.strip() and not txt.startswith("<") and user is None:
                user = txt[:90]

    if mode == "wait_end":
        print(done_last)
    else:
        print(json.dumps({"user": user, "calls": calls}, ensure_ascii=False))
    return 0

if __name__ == "__main__":
    sys.exit(main())
