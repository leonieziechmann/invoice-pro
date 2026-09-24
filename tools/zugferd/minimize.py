#!/usr/bin/env python3
"""Shrinks a failing generated case to a minimal reproduction.

  minimize.py CASE_ID [--corpus DIR]

Greedy delta debugging over the generator's feature vector: every dimension
is set to its simplest value (corpus/gen.py SIMPLE) and `lines` is lowered,
as long as the failure signature (class, rules of both sides, oracle ids)
stays the same. Legal cases stay legal (`gen.allowed`). One Mustang JVM
serves all trials; KoSIT validates each trial in a JVM of its own, which
costs a few seconds (`--no-kosit` skips it when the signature does not
depend on KoSIT).

The minimal case is written to <build dir>/min/<CASE_ID>.typ; add a
`// expect:` header and move it to tools/zugferd/corpus/regression/ to keep
it as a regression case.
"""

import argparse
import json
import sys
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
sys.path.insert(0, str(HERE / "corpus"))

import common  # noqa: E402
import gen  # noqa: E402
import run  # noqa: E402


def evaluate(case, features, work, checker):
    """(signature, row) of `case` with other features."""
    src, facts = gen.render(case["id"], features, case.get("mutation"), case.get("opts"))
    file = work / f"{case['id']}.typ"
    file.write_text(src, encoding="utf-8")
    trial = dict(case, features=features, facts=facts, file=str(file))
    res = run.compile_case(trial, str(work))
    doc = checker.submit(res)
    checker.validate_kosit([res])
    checker.collect(res)
    row = run.make_row(trial, res, doc)
    oracle_ids = sorted({p.split(":")[0] for p in row["oracle"]})
    return (row["cls"], tuple(row["ours"]), tuple(row["official"]), tuple(oracle_ids)), row


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("case")
    ap.add_argument("--corpus", default=None, help="corpus directory (default: <build dir>/corpus)")
    ap.add_argument("--no-kosit", action="store_true",
                    help="skip KoSIT, e.g. when the signature does not involve it (a KoSIT run costs a few seconds per trial)")
    args = ap.parse_args(argv)
    build = common.build_dir()
    corpus = Path(args.corpus) if args.corpus else build / "corpus"
    manifest = json.loads((corpus / "manifest.json").read_text(encoding="utf-8"))
    case = next((c for c in manifest["cases"] if c["id"] == args.case), None)
    if case is None or not case.get("features"):
        print(f"error: {args.case} is not a generated case of {corpus}", file=sys.stderr)
        return 2
    work = build / "min"
    work.mkdir(parents=True, exist_ok=True)
    started = time.perf_counter()
    try:
        checker = run.Checker(build, use_kosit=not args.no_kosit)
    except common.ToolError as e:
        print(f"error: {e}", file=sys.stderr)
        return 2
    try:
        features = dict(case["features"])
        target, row = evaluate(case, features, work, checker)
        print(f"signature: {run.signature(row)}")
        if row["class_ok"] and not row["missing_rules"] and not row["oracle"]:
            print("the case passes: nothing to minimize")
            return 0
        runs, changed = 1, True
        while changed:
            changed = False
            for dim, simple in gen.SIMPLE.items():
                if features[dim] == simple:
                    continue
                values = [v for v in gen.DIMS["lines"] if v < features[dim]] if dim == "lines" else [simple]
                for value in values:
                    trial = dict(features, **{dim: value})
                    if case["population"] == "legal" and not gen.allowed(trial):
                        continue
                    runs += 1
                    if evaluate(case, trial, work, checker)[0] == target:
                        features, changed = trial, True
                        break
        # Leave the minimal case (not the last trial) on disk.
        evaluate(case, features, work, checker)
    finally:
        checker.close()
    kept = {k: v for k, v in features.items() if gen.SIMPLE.get(k) != v}
    print(f"minimal features (other than the simplest values): {kept or '(none)'}")
    print(f"{runs} runs in {time.perf_counter() - started:.1f} s; reproduction: {work / (case['id'] + '.typ')}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
