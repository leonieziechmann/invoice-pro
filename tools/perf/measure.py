#!/usr/bin/env python3
"""Measure the compile time of invoices and the cost of the e-invoice path.

Compiles every document several times, round-robin (so that load from other
processes hits all documents alike), and reports medians. Four methods:

  trace (default)  `typst compile --timings`: the whole compile (`compile
                   once`: evaluation, layout, PDF export) and the time spent
                   in code under src/zugferd/ (see trace_agg.py). Traces vary
                   by a few percent between runs, far less than wall-clock
                   times, and they attribute the time, so they are the basis
                   of the budget.
  --wall           Wall-clock time of untraced compiles, for comparison.
  --instructions   The instructions one compile executes (valgrind's
                   cachegrind, `typst compile --jobs 1`, a fixed creation
                   timestamp): reproducible to a few thousand, so one run per
                   document tells changes far below the noise of a trace
                   apart. It misses what the CPU waits for (page faults,
                   cache misses): confirm a change with traces as well.
  --watch          The recompile time of a live preview: `typst watch` of a
                   copy of each document, which changes the price of its
                   first item to a new value before each run (as someone
                   typing it; nothing of an earlier compile fits it), and the
                   time Typst reports for the recompile. Typst reuses what
                   the edit does not touch, so this is what an edit costs in
                   an editor's preview, not a cold compile.

Documents named `<name>-zf.typ` and `<name>-plain.typ` (see gen_bench.py) form
a pair. For a pair, the cost of the e-invoice path is

  trace:         e-invoice time of the zf compile / total time of the plain
                 compile
  wall, watch:   (re)compile time of the zf compile / that of the plain
                 compile - 1; for watch also the median of the differences
                 of the recompiles of each round (a pair recompiles one
                 after the other), which cancels more of the machine's load
  instructions:  instructions of the zf compile / those of the plain
                 compile - 1 (the e-invoice path and embedding its XML)

The plain compile must not run any e-invoice code: its e-invoice time is
reported as well and should be 0.

Limits turn the measurement into a check (exit status 1 when exceeded):

  --limit b-5=25        the e-invoice cost of the pair b-5 is at most 25 %
  --plain-limit-ms 0.5  no plain compile spends more than 0.5 ms in e-invoice
                        code (trace method only)

Usage:
  tools/perf/measure.py [--root DIR] [--runs 5]
                        [--wall | --instructions | --watch] [--jobs N]
                        [--json FILE] [--limit NAME=PERCENT ...]
                        [--plain-limit-ms MS] documents...

Example (budget of the concept, section 6):
  tools/perf/gen_bench.py --sizes 5,50,300 --kinds b
  tools/perf/measure.py --runs 5 tools/perf/out/bench/b-*.typ \\
      --limit b-5=25 --limit b-50=15 --limit b-300=15 --plain-limit-ms 0.5

Only the Python standard library is needed; `typst` must be on the PATH (or
given with --typst), and `valgrind` for --instructions.

Example (the difference a change makes, e.g. against the commit before it
in a second checkout; see tools/perf/README.md):
  tools/perf/measure.py --instructions --jobs 2 tools/perf/out/bench/b-5-*.typ
  tools/perf/measure.py --instructions --jobs 2 --root /tmp/base \\
      /tmp/base/tools/perf/out/bench/b-5-*.typ

Example (the live preview of the benchmark invoices):
  tools/perf/measure.py --watch --runs 11 tools/perf/out/bench/[br]-*.typ
"""

import argparse
import concurrent.futures
import json
import os
import queue
import re
import shutil
import statistics
import subprocess
import sys
import tempfile
import threading
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


# The creation timestamp of the counted compiles, so that a document that
# uses the date of the day compiles alike on every day (1980-01-01, as
# tytanic's runs of the tests).
TIMESTAMP = "315532800"


def count_instructions(typst, root, document, out_dir):
    """The instructions one compile of `document` executes (cachegrind's
    "I refs"), with one thread, so that the count is reproducible."""
    command = [
        "valgrind", "--tool=cachegrind", "--cache-sim=no", "--cachegrind-out-file=/dev/null",
        typst, "compile", "--jobs", "1", "--creation-timestamp", TIMESTAMP, "--root", root,
        document, os.path.join(out_dir, _name(document) + ".pdf"),
    ]
    process = subprocess.run(command, capture_output=True, text=True)
    for line in process.stderr.splitlines():
        if "I refs" in line:
            return int(line.split()[-1].replace(",", ""))
    sys.stderr.write(process.stderr)
    raise SystemExit(f"compilation failed: {document}")


def measure_instructions(args, documents, names):
    """The report of --instructions: one count per document, as the counts
    do not vary between runs, and for every pair the instructions the
    e-invoice adds."""
    if shutil.which("valgrind") is None:
        raise SystemExit("--instructions needs valgrind on the PATH")
    with tempfile.TemporaryDirectory(prefix="invoice-pro-perf-") as out_dir:
        with concurrent.futures.ThreadPoolExecutor(args.jobs) as pool:
            counts = list(
                pool.map(
                    lambda document: count_instructions(
                        args.typst, args.root, document, out_dir
                    ),
                    documents,
                )
            )
    report = {
        "method": "instructions",
        "typst": subprocess.run(
            [args.typst, "--version"], capture_output=True, text=True
        ).stdout.strip(),
        "documents": {name: {"instructions": n} for name, n in zip(names, counts)},
        "pairs": {},
    }
    for name in names:
        plain = report["documents"].get(name[: -len("-zf")] + "-plain")
        if not name.endswith("-zf") or plain is None:
            continue
        zf = report["documents"][name]["instructions"]
        report["pairs"][name[: -len("-zf")]] = {
            "plain_instructions": plain["instructions"],
            "zf_instructions": zf,
            "einvoice_instructions": zf - plain["instructions"],
            "overhead_pct": 100 * (zf / plain["instructions"] - 1),
        }
    return report


# The edit of the live preview (--watch): the price of the first item, a new
# value before every recompile.
_PRICE = re.compile(r"price: *([0-9]+)(?:\.[0-9]+)?")
# The line `typst watch` prints after each compile, with its time.
_COMPILED = re.compile(r"compiled (successfully|with warnings|with errors) in ([0-9.]+) *(µs|ms|s)\b")
_MILLISECONDS = {"µs": 0.001, "ms": 1.0, "s": 1000.0}


class Watcher:
    """`typst watch` of a copy of `document` next to it (so that its
    relative imports resolve), which `edit` changes. The copy is a hidden
    file, so that a copy an interrupted run leaves behind does not match
    the patterns of the documents (e.g. `b-5-*.typ`)."""

    def __init__(self, typst, root, document, out_dir):
        with open(document, encoding="utf-8") as f:
            self.source = f.read()
        if not _PRICE.search(self.source):
            raise SystemExit(f"--watch changes the price of an item, but {document} has none")
        self.copy = os.path.join(os.path.dirname(document), "." + _name(document) + ".watch.typ")
        self.text = self.source
        self._write(self.text)
        self.lines = queue.Queue()
        self.process = subprocess.Popen(
            [typst, "watch", "--root", root, self.copy, os.path.join(out_dir, _name(document) + ".pdf")],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.PIPE,
            text=True,
            encoding="utf-8",
        )
        threading.Thread(target=self._read, daemon=True).start()

    def _read(self):
        for line in self.process.stderr:
            self.lines.put(line)
        self.lines.put(None)

    def _write(self, text):
        # Replaced at once, so that the watcher never compiles half a file.
        temporary = self.copy + ".tmp"
        with open(temporary, "w", encoding="utf-8") as f:
            f.write(text)
        os.replace(temporary, self.copy)

    def compiled(self, timeout=600, again=60):
        """The time of the next compile that `typst watch` reports, in ms.
        Without a report for `again` seconds, the last edit is written once
        more, in case it came before the watcher watched the file again."""
        deadline = time.monotonic() + timeout
        rewritten = False
        while True:
            try:
                line = self.lines.get(timeout=again)
            except queue.Empty:
                if time.monotonic() > deadline:
                    raise SystemExit(f"typst watch reported no compile within {timeout} s: {self.copy}")
                if not rewritten:
                    self._write(self.text)
                    rewritten = True
                continue
            if line is None:
                raise SystemExit(f"typst watch stopped: {self.copy}")
            match = _COMPILED.search(line)
            if match is None:
                continue
            if match.group(1) == "with errors":
                raise SystemExit(f"the live preview does not compile: {self.copy}")
            return float(match.group(2)) * _MILLISECONDS[match.group(3)]

    def edit(self, n):
        """Changes the price of the first item to its `n`-th new value."""
        self.text = _PRICE.sub(
            lambda m: f"price: {int(m.group(1)) + 1000 + n}.{n % 100:02d}", self.source, count=1
        )
        self._write(self.text)

    def close(self):
        self.process.terminate()
        try:
            self.process.wait(timeout=10)
        except subprocess.TimeoutExpired:
            self.process.kill()
        for path in (self.copy, self.copy + ".tmp"):
            if os.path.exists(path):
                os.remove(path)


def watch_samples(args, documents, names):
    """The recompile times of --watch: one watcher per document, which
    compile one at a time (round-robin); the first recompile of each is a
    warm-up."""
    samples = {name: [] for name in names}
    watchers = []
    with tempfile.TemporaryDirectory(prefix="invoice-pro-perf-") as out_dir:
        try:
            for document in documents:
                watchers.append(Watcher(args.typst, args.root, document, out_dir))
                watchers[-1].compiled()
            for n in range(args.runs + 1):
                for name, watcher in zip(names, watchers):
                    watcher.edit(n)
                    milliseconds = watcher.compiled()
                    if n > 0:
                        samples[name].append({"total": milliseconds * 1000})
        finally:
            for watcher in watchers:
                watcher.close()
    return samples


def compile_samples(args, documents, names):
    """The times of the trace and wall methods: `args.runs` compiles per
    document, round-robin, after a warm-up."""
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
    return samples


def measure(args):
    documents = [os.path.abspath(d) for d in args.documents]
    names = [_name(d) for d in documents]
    if len(set(names)) != len(names):
        raise SystemExit("documents must have distinct file names")
    if args.instructions:
        return measure_instructions(args, documents, names)
    if args.watch:
        samples = watch_samples(args, documents, names)
    else:
        samples = compile_samples(args, documents, names)

    report = {
        "method": "watch" if args.watch else "wall" if args.wall else "trace",
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
        if args.wall or args.watch:
            entry["overhead_pct"] = entry["total_diff_pct"]
        if args.watch:
            # The two documents of a pair recompile one after the other in
            # each round, so the differences of the rounds cancel most of
            # the load of the machine.
            entry["einvoice_ms"] = statistics.median(
                (z["total"] - p["total"]) / 1000
                for z, p in zip(samples[name], samples[pair + "-plain"])
            )
        else:
            entry["einvoice_ms"] = zf["einvoice_ms"]
            entry["einvoice_import_ms"] = zf["einvoice_import_ms"]
            entry["overhead_pct"] = 100 * zf["einvoice_ms"] / plain["total_ms"]
        report["pairs"][pair] = entry
    return report


def print_report(report):
    if report["method"] == "instructions":
        print(f"{report['typst']}, instructions of one compile (--jobs 1), in millions")
        for name, entry in report["documents"].items():
            print(f"{name:16s} {entry['instructions'] / 1e6:12.3f}")
        if report["pairs"]:
            print()
        for pair, entry in report["pairs"].items():
            print(
                f"{pair:10s} e-invoice cost {entry['overhead_pct']:+6.2f} %"
                f"  (plain {entry['plain_instructions'] / 1e6:.3f},"
                f" zf {entry['zf_instructions'] / 1e6:.3f},"
                f" e-invoice {entry['einvoice_instructions'] / 1e6:.3f})"
            )
        return
    runs = "recompiles after an edit" if report["method"] == "watch" else "runs"
    print(f"{report['typst']}, {report['method']}, median of {report['runs']} {runs}")
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
            elif report["method"] == "watch":
                line += f", paired difference {entry['einvoice_ms']:+.1f} ms"
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
    method = parser.add_mutually_exclusive_group()
    method.add_argument("--wall", action="store_true", help="measure wall-clock time")
    method.add_argument(
        "--instructions",
        action="store_true",
        help="count the instructions of one compile per document (valgrind)",
    )
    method.add_argument(
        "--watch",
        action="store_true",
        help="recompile time of a live preview (typst watch) after an edit",
    )
    parser.add_argument(
        "--jobs", type=int, default=1, help="compiles counted in parallel (--instructions)"
    )
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
