#!/usr/bin/env python3
"""P9 root-import delta, deterministic (Q2: at most +1 ms against 0.6.0).
For each compiler and tree, the instructions of an import-only document,
`#import "/<copy>/src/lib.typ": *`, against an empty document (valgrind
cachegrind without cache simulation, `--jobs 1`: repeats agree within a few
thousand instructions; with several threads they drift by up to 0.3 M).
Every path the import touches is hashed, so a tree name one character
longer costs about 0.03 M instructions, and even names of equal length
shift the count by up to 0.25 M (hash-table layout). So the trees are
copied to names of equal length, each under NAMES sets of names (`a0`,
`a1`, .. for the first tree, `b0`, .. for the next), and the delta is the
mean over the sets, with its range. Also: the bytes the import parses (the
files of a traced compile; all bytes and those outside comment lines).
The delta is converted to ms at the import's own rate: the instructions of
the reference import over its untraced wall-clock time (median of RUNS
runs of the empty and the reference document, round-robin), so the noise
of the wall clock enters the rate only, not the delta.
usage: impcount.py RUNS TYPST [TYPST ...] [--trees pristine,repo,..] [--names 4]
The trees live next to proto/ in the work dir of run.sh (<work>/<tree>/src);
the first tree is the reference (pristine 0.6.0). Output: work/impcount/."""
import json, os, re, shutil, statistics, subprocess, sys, time
args = sys.argv[1:]
trees = ["pristine", "repo"]; NAMES = 4
if "--trees" in args:
    i = args.index("--trees"); trees = args[i + 1].split(","); del args[i:i + 2]
if "--names" in args:
    i = args.index("--names"); NAMES = int(args[i + 1]); del args[i:i + 2]
RUNS = int(args[0]); TS = args[1:]
HERE = os.path.dirname(os.path.abspath(__file__)); U = os.path.dirname(os.path.dirname(HERE))
W = os.path.join(HERE, "work", "impcount"); os.makedirs(W, exist_ok=True)
REL = os.path.relpath(W, U)
# equal-length names: tree i, name set k -> "<letter i><k>"
copy = {(t, k): f"{chr(97 + i)}{k}" for i, t in enumerate(trees) for k in range(NAMES)}
docs = {"empty": "// nothing\n"}
for (t, k), c in copy.items():
    shutil.rmtree(f"{W}/{c}", ignore_errors=True); shutil.copytree(f"{U}/{t}/src", f"{W}/{c}/src")
    docs[c] = f'#import "/{REL}/{c}/src/lib.typ": *\n'
for name, src in docs.items(): open(f"{W}/{name}.typ", "w").write(src)
J = ["--jobs", "1"]
def run(T, name, extra=()):
    return subprocess.run([T, "compile", *J, "--root", U, *extra, f"{W}/{name}.typ", f"{W}/{name}.pdf"], capture_output=True, text=True)
def instructions(T, name):
    p = subprocess.run(["valgrind", "--tool=cachegrind", "--cache-sim=no", "--cachegrind-out-file=/dev/null",
                        T, "compile", *J, "--root", U, f"{W}/{name}.typ", f"{W}/{name}.pdf"], capture_output=True, text=True)
    m = re.search(r"I\s+refs:\s+([\d,]+)", p.stderr)
    if not m: sys.exit(f"{name}: {p.stderr[-800:]}")
    return int(m.group(1).replace(",", ""))
def parsed(T, tree):
    c = copy[(tree, 0)]
    tr = f"{W}/{c}-trace.json"; p = run(T, c, ("--timings", tr)); assert p.returncode == 0, p.stderr
    ev = json.load(open(tr)); ev = ev if isinstance(ev, list) else ev["traceEvents"]
    files = sorted({e["args"]["file"].strip('"') for e in ev if e.get("args") and "file" in e["args"]})
    pre = f"/{REL}/{c}/"
    files = [f for f in files if f.startswith(pre + "src/")]
    per = {}
    for f in files:
        s = open(U + f, encoding="utf-8").read()
        code = sum(len(l.encode()) + 1 for l in s.splitlines() if not re.match(r"\s*//", l))
        per[f[len(pre):]] = (len(s.encode()), code)
    return per
out = {}
for T in TS:
    V = subprocess.run([T, "--version"], capture_output=True, text=True).stdout.split()[1]
    ins = {"empty": [instructions(T, "empty") for _ in range(2)]}
    for t in trees: ins[t] = [instructions(T, copy[(t, k)]) for k in range(NAMES)]
    wall = {n: [] for n in ("empty", copy[(trees[0], 0)])}
    for i in range(RUNS):
        for n in (wall if i % 2 == 0 else reversed(list(wall))):
            t0 = time.perf_counter(); p = run(T, n); wall[n].append((time.perf_counter() - t0) * 1000); assert p.returncode == 0
    mean = lambda xs: sum(xs) / len(xs)
    imp_i = mean(ins[trees[0]]) - mean(ins["empty"])
    imp_ms = statistics.median(wall[copy[(trees[0], 0)]]) - statistics.median(wall["empty"])
    rate = imp_i / imp_ms
    pb = {t: parsed(T, t) for t in trees}
    rec = dict(instructions=ins, import_instructions=imp_i, import_ms=imp_ms, rate_per_ms=rate, trees={})
    print(f"{V}: empty {mean(ins['empty'])/1e6:.2f} M, {trees[0]} import {imp_i/1e6:.2f} M instructions in {imp_ms:.1f} ms untraced "
          f"(median of {RUNS}) = {rate/1e6:.2f} M/ms")
    ref = pb[trees[0]]
    for t in trees[1:]:
        ds = [a - b for a, b in zip(ins[t], ins[trees[0]])]; d = mean(ds)
        a = sum(v[0] for v in pb[t].values()) - sum(v[0] for v in ref.values())
        c = sum(v[1] for v in pb[t].values()) - sum(v[1] for v in ref.values())
        rec["trees"][t] = dict(delta_instructions=d, delta_ms=d / rate, parsed_bytes=a, parsed_code_bytes=c,
                               files=len(pb[t]), per_name_set=ds)
        print(f"{V}: {t} delta {d/1e6:+.3f} M instructions ({100*d/imp_i:+.2f} %), {d/rate:+.3f} ms "
              f"[{'PASS' if d / rate <= 1.0 else 'FAIL'} <= 1 ms]; parses {len(pb[t])} files, {a:+d} B ({c:+d} B outside comment lines); "
              f"over {NAMES} name sets {min(ds)/1e6:+.3f} .. {max(ds)/1e6:+.3f} M")
        for f in sorted(set(ref) | set(pb[t])):
            x, y = ref.get(f, (0, 0)), pb[t].get(f, (0, 0))
            if x != y: print(f"    {f}: {x[0]} -> {y[0]} B ({y[0]-x[0]:+d}; code {y[1]-x[1]:+d})")
    out[V] = rec
json.dump(out, open(f"{W}/impcount.json", "w"), indent=1)
