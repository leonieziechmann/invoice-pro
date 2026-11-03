#!/usr/bin/env python3
"""P9 import cost of the root import (`#import "<tree>/src/lib.typ": *`).
1. traced: round-robin compiles with --timings; per file the EXCLUSIVE time of
   its `eval` events (inclusive minus nested evals), median over the runs;
   the delta of the files the prototype changed or added is the import cost
   of the new code (unchanged files only add noise to an inclusive delta).
2. untraced: wall-clock medians of the same import-only documents.
usage: imptrace.py TYPST RUNS"""
import json, subprocess, sys, os, statistics, time
T = sys.argv[1]; N = int(sys.argv[2]); HERE = os.path.dirname(os.path.abspath(__file__)); U = os.path.dirname(os.path.dirname(HERE))
CHANGED = subprocess.run(["git", "-C", f"{U}/repo", "diff", "--name-only", "df934a7", "--", "src"], capture_output=True, text=True).stdout.split()
def exclusive(trace, tree):
    ev = json.load(open(trace)); ev = ev if isinstance(ev, list) else ev["traceEvents"]
    out = {}; stack = []
    for e in ev:
        if e.get("name") != "eval" or not e.get("args"): continue
        f = e["args"].get("file", "").strip('"').replace(f"/{tree}/", "")
        if e["ph"] == "B": stack.append([f, e["ts"], 0.0])
        elif e["ph"] == "E" and stack:
            f0, ts, child = stack.pop(); dur = e["ts"] - ts
            out[f0] = out.get(f0, 0) + (dur - child) / 1000
            if stack: stack[-1][2] += dur
    return out
ex = {"pristine": {}, "repo": {}}; wall = {"pristine": [], "repo": []}
for i in range(N):
    for tree in (("pristine", "repo") if i % 2 == 0 else ("repo", "pristine")):
        doc = f"{HERE}/imp-{tree}.typ"; tr = f"{HERE}/work/imp-{tree}.json"
        subprocess.run([T, "compile", "--root", U, doc, f"{HERE}/work/imp-{tree}.pdf", "--timings", tr], capture_output=True, check=True)
        for f, v in exclusive(tr, tree).items(): ex[tree].setdefault(f, []).append(v)
        t0 = time.perf_counter(); subprocess.run([T, "compile", "--root", U, doc, f"{HERE}/work/imp-{tree}.pdf"], capture_output=True, check=True); wall[tree].append((time.perf_counter() - t0) * 1000)
med = lambda xs: statistics.median(xs) if xs else 0.0
delta = {f: med(ex["repo"].get(f, [])) - med(ex["pristine"].get(f, [])) for f in CHANGED}
V = subprocess.run([T, "--version"], capture_output=True, text=True).stdout.split()[1]
print(f"{V} traced exclusive import time of the changed/new src files (median of {N}), delta vs pristine:")
for f in sorted(delta, key=lambda k: -abs(delta[k])): print(f"   {delta[f]:+.3f} ms  {f}  ({med(ex['pristine'].get(f, [])):.3f} -> {med(ex['repo'].get(f, [])):.3f})")
tot = sum(delta.values())
print(f"{V} traced root import delta (sum over changed/new files): {tot:+.3f} ms")
print(f"{V} untraced import-only compile (median of {N}): pristine {med(wall['pristine']):.1f} ms, prototype {med(wall['repo']):.1f} ms, delta {med(wall['repo'])-med(wall['pristine']):+.1f} ms (VM noise: several ms)")
