#!/usr/bin/env python3
"""Measure the compile time of invoices and the cost of the e-invoice path.

Compiles every document several times, round-robin (so that load from other
processes hits all documents alike), and reports medians. Two methods:

  trace (default)  `typst compile --timings`: the whole compile (`compile
                   once`: evaluation, layout, PDF export) and the time spent
                   in code under src/zugferd/ (see trace_agg.py). Traces vary
                   by a few percent between runs, far less than wall-clock
                   times, and they attribute the time, so they are the basis
                   of the budget.
  --wall           Wall-clock time of untraced compiles, for comparison.

Documents named `<name>-zf.typ` and `<name>-plain.typ` (see gen_bench.py) form
a pair. For a pair, the cost of the e-invoice path is

  trace:  e-invoice time of the zf compile / total time of the plain compile
  wall:   wall time of the zf compile / wall time of the plain compile - 1

The plain compile must not run any e-invoice code: its e-invoice time is
reported as well and should be 0.

Limits turn the measurement into a check (exit status 1 when exceeded):

  --limit b-5=25        the e-invoice cost of the pair b-5 is at most 25 %
  --plain-limit-ms 0.5  no plain compile spends more than 0.5 ms in e-invoice
                        code (trace method only)

Usage:
  tools/perf/measure.py [--root DIR] [--runs 5] [--wall] [--json FILE]
                        [--limit NAME=PERCENT ...] [--plain-limit-ms MS]
                        documents...

Example (budget of the concept, section 6):
  tools/perf/gen_bench.py --sizes 5,50,300 --kinds b
  tools/perf/measure.py --runs 5 tools/perf/out/bench/b-*.typ \\
      --limit b-5=25 --limit b-50=15 --limit b-300=15 --plain-limit-ms 0.5

Only the Python standard library is needed; `typst` must be on the PATH (or
given with --typst).
"""

import argparse
import json
import os
import statistics
import subprocess
import sys
import tempfile
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from trace_agg import aggregate, load_events  # noqa: E402

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))


def _name(path):
    return os.path.splitext(os.path.basename(path))[0]


def compile_once(typst, root, document, out_dir, trace):
    """Compiles `document`; returns (seconds, trace path or None)."""
    name = _name(document)
    command = [typst, "compile", "--root", root]
    trace_path = None
    if trace:
        trace_path = os.path.join(out_dir, name + ".json")
        command += ["--timings", trace_path]
    command += [document, os.path.join(out_dir, name + ".pdf")]
    start = time.perf_counter()
    process = subprocess.run(command, capture_output=True, text=True)
    seconds = time.perf_counter() - start
    if process.returncode != 0:
        sys.stderr.write(process.stderr)
        raise SystemExit(f"compilation failed: {document}")
    return seconds, trace_path


def measure(args):
    documents = [os.path.abspath(d) for d in args.documents]
    names = [_name(d) for d in documents]
    if len(set(names)) != len(names):
        raise SystemExit("documents must have distinct file names")
    samples = {name: [] for name in names}

    with tempfile.TemporaryDirectory(prefix="invoice-pro-perf-") as out_dir:
        for document in documents:  # warm-up: file cache, fonts, packages
            compile_once(args.typst, args.root, document, out_dir, False)
        for _ in range(args.runs):
            for name, document in zip(names, documents):
                seconds, trace_path = compile_once(
                    args.typst, args.root, document, out_dir, not args.wall
                )
                if args.wall:
                    samples[name].append({"total": seconds * 1e6})
                else:
                    result = aggregate(load_events(trace_path))
                    samples[name].append(
                        {
                            key: result[key]
                            for key in ("total", "einvoice", "einvoice_import")
                        }
                    )

    report = {
        "method": "wall" if args.wall else "trace",
        "runs": args.runs,
        "typst": subprocess.run(
            [args.typst, "--version"], capture_output=True, text=True
        ).stdout.strip(),
        "documents": {},
        "pairs": {},
    }
    for name in names:
        entry = {}
        for key in samples[name][0]:
            values = [sample[key] / 1000 for sample in samples[name]]
            entry[key + "_ms"] = statistics.median(values)
            entry[key + "_min_ms"] = min(values)
            entry[key + "_max_ms"] = max(values)
        report["documents"][name] = entry

    for name in names:
        if not name.endswith("-zf"):
            continue
        pair = name[: -len("-zf")]
        plain = report["documents"].get(pair + "-plain")
        if plain is None:
            continue
        zf = report["documents"][name]
        entry = {
            "plain_total_ms": plain["total_ms"],
            "zf_total_ms": zf["total_ms"],
            "total_diff_pct": 100 * (zf["total_ms"] / plain["total_ms"] - 1),
        }
        if args.wall:
            entry["overhead_pct"] = entry["total_diff_pct"]
        else:
            entry["einvoice_ms"] = zf["einvoice_ms"]
            entry["einvoice_import_ms"] = zf["einvoice_import_ms"]
            entry["overhead_pct"] = 100 * zf["einvoice_ms"] / plain["total_ms"]
        report["pairs"][pair] = entry
    return report


def print_report(report):
    print(f"{report['typst']}, {report['method']}, median of {report['runs']} runs")
    trace = report["method"] == "trace"
    header = f"{'document':16s} {'total':>10s}"
    if trace:
        header += f" {'e-invoice':>10s} {'import':>8s}"
    print(header)
    for name, entry in report["documents"].items():
        line = f"{name:16s} {entry['total_ms']:8.1f}ms"
        if trace:
            line += (
                f" {entry['einvoice_ms']:8.1f}ms {entry['einvoice_import_ms']:6.1f}ms"
            )
        print(line)
    if report["pairs"]:
        print()
        for pair, entry in report["pairs"].items():
            line = (
                f"{pair:10s} e-invoice cost {entry['overhead_pct']:+6.1f} %"
                f"  (plain {entry['plain_total_ms']:.1f} ms, zf {entry['zf_total_ms']:.1f} ms"
            )
            if trace:
                line += (
                    f", e-invoice {entry['einvoice_ms']:.1f} ms"
                    f", total difference {entry['total_diff_pct']:+.1f} %"
                )
            print(line + ")")


def check_limits(report, limits, plain_limit_ms):
    failures = []
    for pair, limit in limits.items():
        entry = report["pairs"].get(pair)
        if entry is None:
            failures.append(f"{pair}: pair not measured (need {pair}-plain and {pair}-zf)")
        elif entry["overhead_pct"] > limit:
            failures.append(
                f"{pair}: e-invoice cost {entry['overhead_pct']:.1f} % exceeds {limit} %"
            )
    if plain_limit_ms is not None and report["method"] == "trace":
        for name, entry in report["documents"].items():
            if name.endswith("-plain") and entry["einvoice_ms"] > plain_limit_ms:
                failures.append(
                    f"{name}: {entry['einvoice_ms']:.2f} ms in e-invoice code "
                    f"without an e-invoice (limit {plain_limit_ms} ms)"
                )
    return failures


def main(argv=None):
    parser = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    parser.add_argument("documents", nargs="+", help="Typst documents to compile")
    parser.add_argument(
        "--root", default=REPO, help="project root (default: the repository)"
    )
    parser.add_argument("--runs", type=int, default=5, help="compiles per document")
    parser.add_argument("--wall", action="store_true", help="measure wall-clock time")
    parser.add_argument("--typst", default="typst", help="typst executable")
    parser.add_argument("--json", help="also write the results to this file")
    parser.add_argument(
        "--limit",
        action="append",
        default=[],
        metavar="NAME=PERCENT",
        help="maximum e-invoice cost of a pair, e.g. b-5=25 (repeatable)",
    )
    parser.add_argument(
        "--plain-limit-ms",
        type=float,
        default=None,
        help="maximum time in e-invoice code of a plain compile",
    )
    args = parser.parse_args(argv)

    limits = {}
    for spec in args.limit:
        name, _, value = spec.partition("=")
        if not value:
            parser.error(f"--limit expects NAME=PERCENT, got {spec!r}")
        limits[name] = float(value)

    report = measure(args)
    print_report(report)
    if args.json:
        with open(args.json, "w", encoding="utf-8") as f:
            json.dump(report, f, indent=2)
    failures = check_limits(report, limits, args.plain_limit_ms)
    for failure in failures:
        print("FAIL " + failure, file=sys.stderr)
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
