#!/usr/bin/env python3
"""Aggregate a `typst compile --timings` trace.

`typst compile --timings trace.json ...` writes a Chrome trace: nested begin
("B") and end ("E") events. Function calls, module evaluations and loops carry
the file and line of the code they run, e.g. a call of `process-zugferd`
appears as `func call` with `{"file": "/src/zugferd/zugferd.typ", "line": 44}`
(the line of its definition) and the import of a module as `eval` with the
module's file.

This module sums the events per key. Recursive keys are counted once: the
inclusive time of a key is the time spent in its outermost occurrences. The
cost of the e-invoice path is the time spent in code of `src/zugferd/`: every
event with such a file that is not nested in another one, so the import of
the modules (`eval`) plus the calls from outside (`process-zugferd` and, in
"report" mode, the report). It does not depend on line numbers.

Usage as a script prints a profile of one trace:

    tools/perf/trace_agg.py trace.json [--top N] [--filter SUBSTR]
                            [--modules] [--root DIR]

With `--modules`, it prints what loading each module of the e-invoice path
costs instead: creating its source (mainly parsing), preparing its
evaluation (hashing the syntax tree for the memoized evaluation and
collecting syntax errors) and evaluating it without the modules it loads in
turn; the calls in the tables are named by the function or loop they run
(read from the sources below --root, the repository by default).

Only the Python standard library is needed.
"""

import argparse
import json
import re
import sys
from collections import defaultdict
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]

# Files of the e-invoice path, as the trace names them (relative to --root).
EINVOICE_PREFIX = "/src/zugferd/"

# Span names that carry the file and line of the code they run.
CODE_SPANS = ("func call", "eval", "context", "for loop")


def load_events(path):
    """The events of a trace file, in the order they were recorded."""
    with open(path, encoding="utf-8") as f:
        data = json.load(f)
    return data if isinstance(data, list) else data["traceEvents"]


def event_key(event):
    """`func call /src/x.typ:12` for code spans, the span name otherwise."""
    if event["name"] in CODE_SPANS:
        args = event.get("args") or {}
        return f'{event["name"]} {args.get("file")}:{args.get("line")}'
    return event["name"]


def _file(event):
    return (event.get("args") or {}).get("file") or ""


def aggregate(events, prefix=EINVOICE_PREFIX):
    """Sums the durations of a trace (in microseconds).

    Returns a dictionary with
      total           the `compile once` span: evaluation, layout and export
      compile, pdf    evaluation and layout, and the PDF export
      einvoice        time in code under `prefix` (outermost events only)
      einvoice_import the part of `einvoice` that evaluates modules
      inclusive, self, count   per event key (see `event_key`)
    """
    inclusive = defaultdict(float)
    self_time = defaultdict(float)
    count = defaultdict(int)
    open_keys = defaultdict(int)
    # Per open event: key, start, time of its children, e-invoice depth flag.
    stack = []
    einvoice_depth = 0
    einvoice = 0.0
    einvoice_import = 0.0

    for event in events:
        phase = event["ph"]
        if phase == "B":
            key = event_key(event)
            is_einvoice = _file(event).startswith(prefix)
            stack.append([key, event["ts"], 0.0, is_einvoice, event["name"]])
            open_keys[key] += 1
            if is_einvoice:
                einvoice_depth += 1
        elif phase == "E":
            key, start, children, is_einvoice, name = stack.pop()
            duration = event["ts"] - start
            open_keys[key] -= 1
            if open_keys[key] == 0:
                inclusive[key] += duration
            self_time[key] += duration - children
            count[key] += 1
            if stack:
                stack[-1][2] += duration
            if is_einvoice:
                einvoice_depth -= 1
                if einvoice_depth == 0:
                    einvoice += duration
                    if name == "eval":
                        einvoice_import += duration

    total = inclusive.get("compile once") or inclusive.get("compile") or 0.0
    return {
        "total": total,
        "compile": inclusive.get("compile", 0.0),
        "pdf": inclusive.get("pdf", 0.0),
        "einvoice": einvoice,
        "einvoice_import": einvoice_import,
        "inclusive": dict(inclusive),
        "self": dict(self_time),
        "count": dict(count),
    }


def _tree(events):
    """The spans of a trace as a tree: (key, name, start, end, children)."""
    root = {"key": None, "name": None, "start": 0, "end": 0, "children": []}
    stack = [root]
    for event in events:
        if event["ph"] == "B":
            node = {
                "key": event_key(event),
                "name": event["name"],
                "file": _file(event),
                "start": event["ts"],
                "end": event["ts"],
                "children": [],
            }
            stack[-1]["children"].append(node)
            stack.append(node)
        elif event["ph"] == "E":
            stack.pop()["end"] = event["ts"]
    return root


# Spans of loading a module besides its evaluation (`eval`).
LOAD_SPANS = ("loading file", "hashing file", "create source")


def modules(events, prefix=EINVOICE_PREFIX):
    """What loading each module under `prefix` costs, in microseconds, in the
    order the modules load: `parse` (the `create source` span: parsing and
    numbering the syntax tree), `prepare` (from there to the start of its
    evaluation: hashing the source for the memoized evaluation and collecting
    syntax errors), `eval` (its evaluation without the modules it loads) and
    `total`. A module loads once per compile: the spans of its source
    directly precede its `eval` span, as siblings."""
    out = {}

    def visit(node):
        children = node["children"]
        for i, child in enumerate(children):
            if child["name"] == "eval" and child["file"].startswith(prefix):
                parse = prepare = 0.0
                if i > 0 and children[i - 1]["name"] == "create source":
                    source = children[i - 1]
                    parse = source["end"] - source["start"]
                    prepare = child["start"] - source["end"]
                # Its own evaluation: without the modules it loads.
                nested = 0.0
                grand = child["children"]
                for j, inner in enumerate(grand):
                    if inner["name"] in LOAD_SPANS or inner["name"] == "eval":
                        nested += inner["end"] - inner["start"]
                    if (
                        inner["name"] == "eval"
                        and j > 0
                        and grand[j - 1]["name"] == "create source"
                    ):
                        nested += inner["start"] - grand[j - 1]["end"]
                own = child["end"] - child["start"] - nested
                entry = out.setdefault(
                    child["file"], {"parse": 0.0, "prepare": 0.0, "eval": 0.0}
                )
                entry["parse"] += parse
                entry["prepare"] += prepare
                entry["eval"] += own
            visit(child)

    visit(_tree(events))
    for entry in out.values():
        entry["total"] = entry["parse"] + entry["prepare"] + entry["eval"]
    return out


_DEFINITION = re.compile(r"^\s*#?let\s+([\w-]+)\s*\(")


def name_of(key, root=REPO):
    """The name of the function a `func call` key runs, or the code a `for
    loop` key names, read from its source below `root`; `None` if unknown."""
    match = re.match(r"^(func call|for loop|eval) (/\S+):(\d+)$", key)
    if not match:
        return None
    kind, path, number = match.group(1), match.group(2), int(match.group(3))
    file = Path(root) / path.lstrip("/")
    if kind == "eval" or not file.exists():
        return None
    lines = file.read_text(encoding="utf-8").splitlines()
    if number < 1 or number > len(lines):
        return None
    line = lines[number - 1]
    if kind == "func call":
        found = _DEFINITION.match(line)
        return found.group(1) if found else line.strip()[:40]
    return line.strip()[:40]


def main(argv=None):
    parser = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    parser.add_argument("trace", help="trace written by `typst compile --timings`")
    parser.add_argument("--top", type=int, default=30, help="rows per table")
    parser.add_argument(
        "--filter", default=None, help="only list keys containing this text"
    )
    parser.add_argument(
        "--modules",
        action="store_true",
        help="the cost of loading each module of the e-invoice path",
    )
    parser.add_argument(
        "--root", default=str(REPO), help="root of the sources (for names)"
    )
    args = parser.parse_args(argv)

    events = load_events(args.trace)
    result = aggregate(events)
    total = result["total"] or 1.0

    def ms(us):
        return f"{us / 1000:9.1f} ms"

    if args.modules:
        loaded = modules(events)
        print(f"e-invoice module import {ms(result['einvoice_import'])}")
        print(
            f"{'parse':>9}    {'prepare':>9}    {'eval':>9}    "
            f"{'total':>9}    {'KiB':>6}  module"
        )
        for file, entry in sorted(loaded.items(), key=lambda kv: -kv[1]["total"]):
            path = Path(args.root) / file.lstrip("/")
            size = path.stat().st_size / 1024 if path.exists() else float("nan")
            print(
                f"{ms(entry['parse'])} {ms(entry['prepare'])} {ms(entry['eval'])} "
                f"{ms(entry['total'])} {size:6.1f}  {file}"
            )
        sums = {k: sum(e[k] for e in loaded.values()) for k in ("parse", "prepare", "eval", "total")}
        print(
            f"{ms(sums['parse'])} {ms(sums['prepare'])} {ms(sums['eval'])} "
            f"{ms(sums['total'])}          sum"
        )
        return 0

    print(f"total (compile once) {ms(result['total'])}")
    print(f"  compile            {ms(result['compile'])}")
    print(f"  pdf export         {ms(result['pdf'])}")
    print(
        f"e-invoice path       {ms(result['einvoice'])}"
        f"  ({100 * result['einvoice'] / total:.1f} % of total)"
    )
    print(f"  module import      {ms(result['einvoice_import'])}")

    def rows(values):
        items = [
            (key, value)
            for key, value in values.items()
            if args.filter is None or args.filter in key
        ]
        return sorted(items, key=lambda item: -item[1])[: args.top]

    def label(key):
        name = name_of(key, args.root)
        return f"{key}  ({name})" if name else key

    print(f"\ninclusive time, top {args.top}:")
    for key, value in rows(result["inclusive"]):
        print(
            f"  {ms(value)} {100 * value / total:5.1f} %"
            f"  n={result['count'][key]:7d}  {label(key)}"
        )
    print(f"\nself time, top {args.top}:")
    for key, value in rows(result["self"]):
        print(
            f"  {ms(value)} {100 * value / total:5.1f} %"
            f"  n={result['count'][key]:7d}  {label(key)}"
        )
    return 0


if __name__ == "__main__":
    sys.exit(main())
