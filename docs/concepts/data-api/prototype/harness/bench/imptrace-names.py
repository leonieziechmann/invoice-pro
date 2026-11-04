#!/usr/bin/env python3
"""P9 root-import delta, traced, controlled for the tree name (Q2: at most
+1 ms against 0.6.0). imptrace.py compares /pristine with /repo, but the
name of a tree alone moves its import: the same code under another name
reads 1.5 to 3.7 ms apart traced and up to 9 ms untraced, more than the
budget. So, as impcount.py does, each tree is copied under NAMES names of
equal length (`a0`.. pristine, `b0`.. pristine again, `c0`.. the prototype),
each copy is compiled with --timings round-robin, its import is the sum of
the exclusive `eval` time of all files (median of RUNS), and a tree's import
is the mean over its names. The A/A pair (b - a, identical code) shows the
floor of the method.
usage: imptrace-names.py TYPST RUNS [--names 4]
Output: work/imptrace-names/."""
import json, os, shutil, statistics, subprocess, sys
args = sys.argv[1:]; NAMES = 4
if "--names" in args:
    i = args.index("--names"); NAMES = int(args[i + 1]); del args[i:i + 2]
T, N = args[0], int(args[1])
HERE = os.path.dirname(os.path.abspath(__file__)); U = os.path.dirname(os.path.dirname(HERE))
W = os.path.join(HERE, "work", "imptrace-names"); os.makedirs(W, exist_ok=True); REL = os.path.relpath(W, U)
trees = (("pristine", "pristine", "a"), ("pristine again", "pristine", "b"), ("prototype", "repo", "c"))
docs = {}
for name, src, letter in trees:
    for k in range(NAMES):
        c = f"{letter}{k}"; shutil.rmtree(f"{W}/{c}", ignore_errors=True); shutil.copytree(f"{U}/{src}/src", f"{W}/{c}/src")
        open(f"{W}/{c}.typ", "w").write(f'#import "/{REL}/{c}/src/lib.typ": *\n'); docs[c] = name
def exclusive(trace):
    ev = json.load(open(trace)); ev = ev if isinstance(ev, list) else ev["traceEvents"]
    total = 0.0; stack = []
    for e in ev:
        if e.get("name") != "eval" or not e.get("args"): continue
        if e["ph"] == "B": stack.append([e["ts"], 0.0])
        elif e["ph"] == "E" and stack:
            ts, child = stack.pop(); dur = e["ts"] - ts; total += (dur - child) / 1000
            if stack: stack[-1][1] += dur
    return total
ms = {c: [] for c in docs}
for i in range(N):
    for c in (list(docs) if i % 2 == 0 else list(reversed(docs))):
        subprocess.run([T, "compile", "--root", U, f"{W}/{c}.typ", f"{W}/x.pdf", "--timings", f"{W}/x.json"], check=True, capture_output=True)
        ms[c].append(exclusive(f"{W}/x.json"))
V = subprocess.run([T, "--version"], capture_output=True, text=True).stdout.split()[1]
per = {c: statistics.median(v) for c, v in ms.items()}
tree = {name: statistics.mean(per[c] for c in docs if docs[c] == name) for name, _, _ in trees}
print(f"{V} traced import per name (median of {N}): " + " ".join(f"{c} {per[c]:.2f}" for c in docs) + " ms")
print(f"{V} traced root import delta over {NAMES} names: prototype {tree['prototype'] - tree['pristine']:+.2f} ms, "
      f"A/A (pristine again) {tree['pristine again'] - tree['pristine']:+.2f} ms")
