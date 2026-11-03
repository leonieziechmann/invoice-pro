#!/usr/bin/env python3
"""P9 performance (round-robin medians, untraced wall clock unless noted).
 1. hydrated 300 rows vs hand-written (pristine 0.6.0 and prototype), kinds b
    and t, zugferd auto (XRechnung): gate hydrated <= 0.6 x hand-written;
 2. decoder: decode + check of 300 vs 5 rows (no layout): ms per row, gate
    <= 0.4 ms/row;
 3. lazy modules: a traced compile of the hand-written b-300 e-invoice and of
    the template on the prototype loads none of src/contract/*.
usage: p9.py TYPST RUNS"""
import json, subprocess, sys, os, statistics, time, glob
T = sys.argv[1]; N = int(sys.argv[2]); HERE = os.path.dirname(os.path.abspath(__file__)); U = os.path.dirname(os.path.dirname(HERE)); EQ = f"{U}/proto/eq"
V = subprocess.run([T, "--version"], capture_output=True, text=True).stdout.split()[1]
os.makedirs(f"{HERE}/work", exist_ok=True)
def run(args):
    t0 = time.perf_counter(); p = subprocess.run([T] + args, capture_output=True, text=True)
    dt = time.perf_counter() - t0
    if p.returncode: sys.exit("compile failed: " + " ".join(args) + "\n" + p.stderr[-800:])
    return dt
C = ["--root", U, "--input", "zf=auto", "--creation-timestamp", "1767225600", "--pdf-standard", "a-3b"]
out = {"typst": V, "runs": N}
for k in ("b", "t"):
    variants = {
        "hand-pristine": ["compile"] + C + ["--input", "lib=pristine", f"{EQ}/hand/{k}-300.typ", f"{HERE}/work/h.pdf"],
        "hand-prototype": ["compile"] + C + ["--input", "lib=repo", f"{EQ}/hand/{k}-300.typ", f"{HERE}/work/h2.pdf"],
        "hydrated": ["compile"] + C + ["--input", f"invoice-pro-data-file=data/{k}-300.json", f"{EQ}/skeleton.typ", f"{HERE}/work/d.pdf"],
    }
    times = {v: [] for v in variants}
    names = list(variants)
    for i in range(N):
        order = names if i % 2 == 0 else names[::-1]
        for v in order: times[v].append(run(variants[v]))
    med = {v: statistics.median(x) for v, x in times.items()}
    ratio = med["hydrated"] / med["hand-pristine"]
    out[f"{k}-300"] = {"median_s": med, "ratio_hydrated_vs_hand_pristine": ratio, "ratio_vs_hand_prototype": med["hydrated"] / med["hand-prototype"], "all": times}
    print(f"{V} {k}-300 zf=auto: hand pristine {med['hand-pristine']:.2f} s, hand prototype {med['hand-prototype']:.2f} s, hydrated {med['hydrated']:.2f} s -> {ratio:.2f}x ({'PASS' if ratio <= 0.6 else 'FAIL'} <= 0.6)", flush=True)
# 2. decoder
stub = f"{HERE}/decode-stub.typ"
dec = {}
for k in ("b", "t"):
    ts = {n: [] for n in ("none", 5, 300)}
    for i in range(N):
        for n in (("none", 5, 300) if i % 2 == 0 else (300, 5, "none")):
            args = ["compile", "--root", U, "--input", f"f=/proto/eq/data/{k}-{300 if n == 'none' else n}.json", "--input", f"mode={'none' if n == 'none' else 'check'}", stub, f"{HERE}/work/s.pdf"]
            ts[n].append(run(args))
    m = {n: statistics.median(v) for n, v in ts.items()}
    per = (m[300] - m[5]) / 295 * 1000
    dec[k] = {"median_s": {str(n): v for n, v in m.items()}, "ms_per_row": per, "ms_300_rows": (m[300] - m["none"]) * 1000}
    print(f"{V} decoder {k}: check(300 rows) {dec[k]['ms_300_rows']:.0f} ms over the stub without decoding; (300 - 5 rows)/295 = {per:.3f} ms/row ({'PASS' if per <= 0.4 else 'FAIL'} <= 0.4)", flush=True)
out["decoder"] = dec
# 3. lazy modules
lazy = {}
for name, args in {
    "hand b-300 e-invoice": ["compile"] + C + ["--input", "lib=repo", f"{EQ}/hand/b-300.typ", f"{HERE}/work/l1.pdf"],
    "template": ["compile", "--root", f"{U}/repo", "--creation-timestamp", "1767225600", f"{U}/repo/template/_tpl.typ", f"{HERE}/work/l2.pdf"],
}.items():
    tr = f"{HERE}/work/lazy.json"
    if name == "template":
        open(f"{U}/repo/template/_tpl.typ", "w").write(open(f"{U}/repo/template/invoice.typ").read().replace("@preview/invoice-pro:0.6.0", "/src/lib.typ"))
    subprocess.run([T] + args + ["--timings", tr], capture_output=True, check=True)
    if name == "template": os.remove(f"{U}/repo/template/_tpl.typ")
    ev = json.load(open(tr)); ev = ev if isinstance(ev, list) else ev["traceEvents"]
    files = sorted({e["args"]["file"].strip('"') for e in ev if e.get("args") and "file" in e["args"]})
    loaded = [f for f in files if "/src/contract/" in f]
    lazy[name] = loaded
    print(f"{V} lazy: {name}: src/contract/* in trace: {loaded if loaded else 'none'} ({'PASS' if not loaded else 'FAIL'})", flush=True)
out["lazy"] = lazy
json.dump(out, open(f"{U}/proto/out/p9-{V}.json", "w"), indent=1)
