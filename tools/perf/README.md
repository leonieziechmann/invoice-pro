# Performance tools

Scripts to measure what the e-invoice (ZUGFeRD / Factur-X) path costs and to check that an optimization leaves the output unchanged. They are development tools: they are not part of the published package and need Python 3 (standard library only, except `compare_outputs.py`, see below) and `typst` on the `PATH`.

## Budget

The e-invoice path of an invoice may cost at most **15 %** (target) and never more than **25 %** (hard ceiling) of the compile time of the same invoice without e-invoice, measured on the benchmark invoices with 5, 50 and 300 lines, median of at least 5 runs.

The cost is measured with `typst compile --timings` rather than with a stopwatch: traces vary by a few percent between runs, wall-clock times of a 300-line invoice on a shared machine by 100 ms and more, and a trace shows where the time goes. The metric is

```text
e-invoice cost = time spent in code of src/zugferd/ (zf compile)
                 / total time of the plain compile
```

"Time in code of `src/zugferd/`" counts every trace event of a file in `src/zugferd/` that is not nested in another one: the import of the e-invoice modules and the calls from outside, i.e. `process-zugferd` (model, validation, XML) and, in `"report"` mode, the report. It does not depend on line numbers. The total time is the `compile once` span: evaluation, layout and PDF export.

A plain invoice (`zugferd: none`) must not run e-invoice code at all: the e-invoice modules are only loaded when `zugferd` is set.

## Scripts

| Script               | Purpose                                                                                                                                   |
| :------------------- | :---------------------------------------------------------------------------------------------------------------------------------------- |
| `gen_bench.py`       | Writes the benchmark invoices `<kind>-<lines>-plain.typ` and `<kind>-<lines>-zf.typ` to `tools/perf/out/bench/` (ignored by git).         |
| `measure.py`         | Compiles documents several times (round-robin), prints medians and the e-invoice cost of each plain/zf pair, optionally checks limits.    |
| `trace_agg.py`       | Profile of a single `--timings` trace: phases, e-invoice time, inclusive and self time per function, module and loop.                     |
| `compare_outputs.py` | Compiles documents in two checkouts and compares diagnostics, PDF bytes and, if they differ, the attachments (the XML) and the page text. |

Benchmark kinds of `gen_bench.py`:

- `b` (basic): German seller and buyer, one VAT rate, net prices. With the default `--profile auto`, the e-invoice is XRechnung 3.0.
- `r` (rich): gross prices, three VAT categories (19 %, 7 %, exempt), a discount on every fifth line, a document discount, a surcharge and a prepayment.

## Usage

Measure the budget (about one minute for 5 runs):

```bash
tools/perf/gen_bench.py --sizes 5,50,300 --kinds b
tools/perf/measure.py --runs 5 tools/perf/out/bench/b-*.typ
```

It prints the median total time, e-invoice time and e-invoice import time of every document and, for every pair, the e-invoice cost and the difference of the total times.

As a check, e.g. in CI: `--limit` fails (exit status 1) when the e-invoice cost of a pair exceeds the given percentage, `--plain-limit-ms` when a plain compile spends more than the given time in e-invoice code, and `--json` writes the results for further processing:

```bash
tools/perf/measure.py --runs 5 tools/perf/out/bench/b-*.typ \
  --limit b-5=25 --limit b-50=15 --limit b-300=15 --plain-limit-ms 0.5 \
  --json perf.json
```

`--wall` measures wall-clock time instead (untraced compiles), for comparison.

Profile a single compile:

```bash
typst compile --root . --timings trace.json tools/perf/out/bench/b-300-zf.typ /tmp/b.pdf
tools/perf/trace_agg.py trace.json --filter /src/zugferd/
```

Check that a change keeps every output identical, e.g. against the commit before it (`compare_outputs.py` needs the Python package `pypdf` to compare the attachments and the page text of PDFs that differ):

```bash
git worktree add /tmp/base HEAD~1
tools/perf/gen_bench.py && tools/perf/gen_bench.py --out /tmp/base/tools/perf/out/bench
tools/perf/compare_outputs.py --base /tmp/base --head . --mode report --mode ignore \
  tests/integration/zugferd-basic/test.typ tools/perf/out/bench/b-50-zf.typ
```

`--from-file` reads the documents from a file, one per line. With `--pdf-standard a-3b`, the PDFs carry the AFRelationship of their attachments, so that it is compared as well. A document that cannot be exported as a PDF (e.g. a test with several e-invoices, whose attachments share a name) is compared by the attachments `typst query` lists. Documents that import the published package (`@preview/invoice-pro:<version>`, e.g. the template) resolve it through the package path, not through the checkout: compare a copy that imports `/src/lib.typ` instead. Tests that use tytanic's `catch` do not compile with plain `typst` and can only be compared by their error message.

## Keeping the e-invoice path cheap

These rules come from measurements of the e-invoice path. They apply to all code that runs for every invoice or for every line.

1. Compile regular expressions once at module level, never inside a function: `regex(..)` costs 0.05 to 0.25 ms per call.
2. A function called per line gets the line (and small flags), never the whole model or `ctx`. Typst hashes the arguments of every closure call to memoize it; for a 300-line model that is about 70 µs per call.
3. Use `for` loops instead of `.map(..)`, `.filter(..)` or `.find(..)` with a closure in code that runs per line or per element (a few µs per closure call, plus hashing).
4. Keep code lists as dictionaries (`code in list` is a hash lookup, while a search in an array of 2 000 codes costs about 7 µs) and build them without a closure per code.
5. Call `process-zugferd` once per compile, outside of `context` and outside of loom's measure pass.
6. Bound every iterative walk per line: Typst stops a `while` loop after 10 000 iterations, which a loop over all elements of a large invoice reaches.
7. Load the e-invoice modules only when `zugferd` is set.
