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

Where the time goes is measured in the [budget table](#budget-table) below.

## Scripts

| Script               | Purpose                                                                                                                                                                           |
| :------------------- | :-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `gen_bench.py`       | Writes the benchmark invoices `<kind>-<lines>-plain.typ` and `<kind>-<lines>-zf.typ` to `tools/perf/out/bench/` (ignored by git).                                                 |
| `measure.py`         | Compiles documents several times (round-robin), prints medians and the e-invoice cost of each plain/zf pair, optionally checks limits.                                            |
| `gate.py`            | The performance gate of CI (`scripts/perf-gate`, see `tests/TESTING.md`).                                                                                                         |
| `trace_agg.py`       | Profile of a single `--timings` trace: phases, e-invoice time, inclusive and self time per function, module and loop; with `--modules`, what loading each e-invoice module costs. |
| `compare_outputs.py` | Compiles documents in two checkouts and compares diagnostics, PDF bytes and, if they differ, the attachments (the XML) and the page text.                                         |

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

The tables name the function a call runs and the code a loop runs, read from the sources of the repository; `--root DIR` reads them from another checkout, e.g. the one the trace was made in. With `--modules`, it prints what loading each module of the e-invoice path costs instead: parsing its source, preparing its evaluation (hashing the syntax tree for Typst's memoized evaluation and collecting syntax errors) and evaluating it, without the modules it loads in turn:

```bash
tools/perf/trace_agg.py trace.json --modules
```

Check that a change keeps every output identical, e.g. against the commit before it (`compare_outputs.py` needs the Python package `pypdf` to compare the attachments and the page text of PDFs that differ):

```bash
git worktree add /tmp/base HEAD~1
tools/perf/gen_bench.py && tools/perf/gen_bench.py --out /tmp/base/tools/perf/out/bench
tools/perf/compare_outputs.py --base /tmp/base --head . --mode report --mode ignore \
  tests/integration/zugferd-basic/test.typ tools/perf/out/bench/b-50-zf.typ
```

`--from-file` reads the documents from a file, one per line. With `--pdf-standard a-3b`, the PDFs carry the AFRelationship of their attachments, so that it is compared as well. A document that cannot be exported as a PDF (e.g. a test with several e-invoices, whose attachments share a name) is compared by the attachments `typst query` lists. Documents that import the published package (`@preview/invoice-pro:<version>`, e.g. the template) resolve it through the package path, not through the checkout: compare a copy that imports `/src/lib.typ` instead. Tests that use tytanic's `catch` do not compile with plain `typst` and can only be compared by their error message.

## Measuring small changes

Timings of the same checkout vary from run to run, and part of the variation is systematic: the page faults of the allocator depend on the layout of the memory, which any change of the sources shifts. Two identical copies of the checkout measured up to about 1 ms apart in the median of the paired differences of 21 interleaved runs of the 5-line invoice, and removing an unused function measured 1 to 3 ms slower while it executed fewer instructions. A trace comparison therefore only resolves effects of more than about 1 ms at 5 lines. Compare A and B interleaved (A B, B A, ...), 21 runs or more, and take the median of the paired differences.

Smaller effects show in the number of instructions a compile executes, which with `--jobs 1` is reproducible to a few thousand (with parallel jobs it varies by about 0.05 %):

```bash
valgrind --tool=cachegrind --cache-sim=no --cachegrind-out-file=/dev/null \
  typst compile --jobs 1 --root . tools/perf/out/bench/b-5-zf.typ /tmp/b.pdf 2>&1 | grep "I refs"
```

The count of the zf invoice minus that of the plain invoice is the work the e-invoice adds: the e-invoice path and embedding the XML in the PDF. Instructions miss what the CPU waits for (page faults, cache misses), so confirm a change with a trace as well.

## Budget table

Measured on a shared virtual machine with 4 cores and typst 0.14.2, before and after the performance work of the branch `perf/zugferd-fixed-costs` (6125e79 → 7a631be), on the `b` benchmark invoices. Times are medians of interleaved traced runs (11, 5 and 3 runs at 5, 50 and 300 lines); at 300 lines, the load of other processes moved the medians by up to 20 ms between measurements.

The e-invoice path by step, in ms (inclusive times of the functions `process-zugferd` calls):

| Step                                   |     5 lines |    50 lines |     300 lines |
| :------------------------------------- | ----------: | ----------: | ------------: |
| Module import                          | 25.1 → 24.1 | 26.7 → 24.2 |   25.4 → 23.4 |
| `build-model`                          |   6.7 → 4.9 |  17.1 → 8.5 |   84.4 → 36.7 |
| `validate`                             |   1.7 → 2.1 |   5.5 → 3.5 |   14.0 → 12.5 |
| `build-tree`                           |   1.3 → 1.1 |   6.7 → 5.0 |   45.4 → 26.1 |
| `dict-to-xml` (serializer, G1 and G2)  |  13.4 → 8.0 | 30.1 → 19.5 |  110.2 → 94.1 |
| of which loading the guard tables      |   2.5 → 0.8 |   2.6 → 0.8 |     2.6 → 0.8 |
| G4 (Typst parses the XML)              |   0.2 → 0.3 |   1.3 → 1.3 |     6.6 → 6.5 |
| `process-zugferd` in total             | 26.0 → 19.4 | 65.3 → 46.1 | 270.7 → 183.2 |
| E-invoice path (import and processing) | 51.2 → 43.5 | 92.2 → 70.2 | 297.1 → 206.5 |

`process-zugferd` takes about 3 ms more than its steps at 5 lines, mostly for hashing, at its first call, the closures it reaches (their syntax trees and captured values) for memoization. `validate` was not changed; its differences come from the model it gets and from the noise described above.

Loading the modules, in ms (5 lines; each module once per compile):

| Module                         | KiB | parse | prepare | eval | total | before |
| :----------------------------- | --: | ----: | ------: | ---: | ----: | -----: |
| `validate.typ`                 | 111 |   5.0 |     0.8 |  1.4 |   7.2 |    7.1 |
| `model.typ`                    |  56 |   3.3 |     0.5 |  1.3 |   5.0 |    5.6 |
| `guard/write.typ`              |  31 |   1.8 |     0.3 |  1.1 |   3.3 |    3.7 |
| `codelists.typ`                |  16 |   0.2 |     0.0 |  2.7 |   2.9 |    3.0 |
| `build.typ`                    |  23 |   1.2 |     0.2 |  0.3 |   1.7 |    1.7 |
| `guard/lists.typ`              |  22 |   0.5 |     0.1 |  0.5 |   1.1 |    1.1 |
| `zugferd.typ`                  | 5.5 |   0.3 |     0.0 |  0.3 |   0.6 |    0.7 |
| `document.typ`                 | 7.9 |   0.3 |     0.1 |  0.2 |   0.6 |    0.5 |
| `xml.typ`                      | 4.2 |   0.2 |     0.0 |  0.1 |   0.4 |    0.7 |
| `profile.typ`                  | 6.1 |   0.2 |     0.0 |  0.1 |   0.3 |    0.3 |
| `guard/xrechnung.typ` (before) |     |       |         |      |       |    2.4 |
| `report.typ` (before)          |     |       |         |      |       |    0.3 |

Before, the guard tables were Typst modules (`guard/xrechnung.typ`: 2.4 ms); they are JSON now, which the serializer reads in 0.8 ms. `report.typ` loads only when there is something to report. The rest of the import is mostly the size of the sources: parsing code costs 45 to 60 µs per KiB (long string literals far less), preparing 7 to 10 µs per KiB. `eval` of `codelists.typ` builds dictionaries of its code lists.

Instructions executed (millions, `--jobs 1`, see [above](#measuring-small-changes)):

| Invoice                                 | 5 lines | 50 lines | 300 lines |
| :-------------------------------------- | ------: | -------: | --------: |
| Plain compile (the same before)         |   1 135 |    3 175 |    14 520 |
| E-invoice path (zf minus plain), before |   196.6 |    326.6 |   1 030.6 |
| E-invoice path (zf minus plain), after  |   162.7 |    278.8 |     922.1 |
| Change                                  |   −17 % |    −15 % |     −11 % |

## Keeping the e-invoice path cheap

These rules come from measurements of the e-invoice path. They apply to all code that runs for every invoice or for every line. Instruction counts are from `cachegrind` (see above); on the test machine, the e-invoice path executes about 4 000 instructions per microsecond.

1. Compile regular expressions once at module level, never inside a function: `regex(..)` costs 0.05 to 0.4 ms per call.
2. A function called per line gets the line (and small flags), never the whole model or `ctx`. Typst hashes the arguments of every closure call to memoize it; for a 300-line model that is about 70 µs per call.
3. Use `for` loops instead of `.map(..)`, `.filter(..)` or `.find(..)` with a closure in code that runs per line or per element (a few µs per closure call, plus hashing).
4. Look codes up in a dictionary (a hash lookup, about 500 instructions) or in a string of codes between spaces (`" " + code + " " in list`, about 6 000 instructions in a list of 2 000 codes), never in an array (about 60 000). A dictionary costs about 4 400 instructions per code to build when its module loads, a string literal only its parsing; code lists that every e-invoice loads are strings for that reason (`guard/lists.typ`).
5. Call `process-zugferd` once per compile, outside of `context` and outside of loom's measure pass.
6. Bound every iterative walk per line: Typst stops a `while` loop after 10 000 iterations, which a loop over all elements of a large invoice reaches.
7. Load the e-invoice modules only when `zugferd` is set.
8. Count calls in code that runs per element or per line. A call of a function or method (e.g. `type(..)`, `.at(..)`) costs 4 000 to 5 500 instructions, as does a call of a closure whose result Typst has memoized; an operator, a field access or `in` costs about 500, a `let` in a loop body about 2 400, destructuring about 1 300 per name. Prefer operators and fields, and leave out bookkeeping that can be derived: the serializer tells that an element wrote no child from the index of the last child written, without a counter.
9. At the first call of a closure in a compile, Typst hashes the closure with its syntax tree and everything it captures, closures included; the arguments, deeply, at every call. Large constant data (tables, lists) belongs in values a function captures or loads, not in its arguments; a call on small arguments (an index, a string) is cheap to memoize.
10. Every module the e-invoice path loads costs its size (see the budget table), and the closures a call reaches cost hashing once. Code that only some invoices need goes into a module of its own, imported in the function that needs it (`import "rare.typ": other-child` in the function body): Typst parses the module only when the import runs (`guard/rare.typ`, `keys.typ`, `units.typ`, `report.typ`).
11. Generated data that the code only reads is JSON, read with `json(..)`: Typst reads it several times faster than the same data as a module (the XRechnung guard table: 0.8 ms instead of 2.4 ms).
12. Test the common case first, with one cheap check: most texts of an invoice are plain ASCII, which one regular expression tells, so that `plain-text` and its replacements run only for the others; most amounts are decimals already (`type(value) == decimal`), so they are not converted again.
