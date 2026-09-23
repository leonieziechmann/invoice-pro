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

Only the Python standard library is needed.
"""

import argparse
import json
import sys
from collections import defaultdict

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


def main(argv=None):
    parser = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    parser.add_argument("trace", help="trace written by `typst compile --timings`")
    parser.add_argument("--top", type=int, default=30, help="rows per table")
    parser.add_argument(
        "--filter", default=None, help="only list keys containing this text"
    )
    args = parser.parse_args(argv)

    result = aggregate(load_events(args.trace))
    total = result["total"] or 1.0

    def ms(us):
        return f"{us / 1000:9.1f} ms"

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

    print(f"\ninclusive time, top {args.top}:")
    for key, value in rows(result["inclusive"]):
        print(
            f"  {ms(value)} {100 * value / total:5.1f} %"
            f"  n={result['count'][key]:7d}  {key}"
        )
    print(f"\nself time, top {args.top}:")
    for key, value in rows(result["self"]):
        print(
            f"  {ms(value)} {100 * value / total:5.1f} %"
            f"  n={result['count'][key]:7d}  {key}"
        )
    return 0


if __name__ == "__main__":
    sys.exit(main())
