#!/usr/bin/env python3
"""P9 side measurement: the prototype plus design C's API-neutral format-item
PR (S7a, branch proto-s7a, worktree <u>/repo-s7a): b-300 and t-300 e-invoices,
hydrated vs hand-written on pristine 0.6.0 (round-robin medians), and md5
equality of all three PDFs. usage: p9-s7a.py TYPST RUNS"""
import subprocess, sys, os, statistics, time, hashlib
T = sys.argv[1]; N = int(sys.argv[2]); HERE = os.path.dirname(os.path.abspath(__file__)); U = os.path.dirname(os.path.dirname(HERE)); EQ = f"{U}/proto/eq"
V = subprocess.run([T, "--version"], capture_output=True, text=True).stdout.split()[1]
C = ["--root", U, "--input", "zf=auto", "--creation-timestamp", "1767225600", "--pdf-standard", "a-3b"]
md5 = lambda p: hashlib.md5(open(p, "rb").read()).hexdigest()[:12]
for k in ("b", "t"):
    v = {"hand-pristine": (["--input", "lib=pristine", f"{EQ}/hand/{k}-300.typ"], "hp"),
         "hand-s7a": (["--input", "lib=repo-s7a", f"{EQ}/hand/{k}-300.typ"], "hs"),
         "hydrated-s7a": (["--input", f"invoice-pro-data-file=data/{k}-300.json", f"{EQ}/skeleton-s7a.typ"], "ds")}
    ts = {n: [] for n in v}
    for i in range(N):
        for n in (list(v) if i % 2 == 0 else list(v)[::-1]):
            a, o = v[n]; t0 = time.perf_counter()
            subprocess.run([T, "compile"] + C + a + [f"{HERE}/work/{o}.pdf"], check=True, capture_output=True)
            ts[n].append(time.perf_counter() - t0)
    m = {n: statistics.median(x) for n, x in ts.items()}
    same = len({md5(f"{HERE}/work/{o}.pdf") for _, o in v.values()}) == 1
    r = m["hydrated-s7a"] / m["hand-pristine"]
    print(f"{V} S7a {k}-300 zf=auto: hand pristine {m['hand-pristine']:.2f} s, hand+S7a {m['hand-s7a']:.2f} s, hydrated+S7a {m['hydrated-s7a']:.2f} s -> {r:.2f}x ({'PASS' if r <= 0.6 else 'FAIL'} <= 0.6); md5 all equal: {same}", flush=True)
