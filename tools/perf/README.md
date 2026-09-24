# Performance tools

Scripts to measure what the e-invoice (ZUGFeRD / Factur-X) path costs and to check that an optimization leaves the output unchanged. They are development tools: they are not part of the published package and need Python 3 (standard library only, except `compare_outputs.py`, see below) and `typst` on the `PATH`.

## Budget

The e-invoice path of an invoice may cost at most **15 %** (target) and never more than **25 %** (hard ceiling) of the compile time of the same invoice without e-invoice, measured on the benchmark invoices with 5, 50 and 300 lines, median of at least 5 runs. At 5 lines, the target is informational: the maintainer accepts a share above 15 % there as long as the live preview stays comfortable (see [Live preview](#live-preview)); the hard ceiling and the targets at 50 and 300 lines hold.

The cost is measured with `typst compile --timings` rather than with a stopwatch: traces vary by a few percent between runs, wall-clock times of a 300-line invoice on a shared machine by 100 ms and more, and a trace shows where the time goes. The metric is

```text
e-invoice cost = time spent in code of src/zugferd/ (zf compile)
                 / total time of the plain compile
```

"Time in code of `src/zugferd/`" counts every trace event of a file in `src/zugferd/` that is not nested in another one: the import of the e-invoice modules and the calls from outside, i.e. `process-zugferd` (model, validation, XML) and, in `"report"` mode, the report. It does not depend on line numbers. The total time is the `compile once` span: evaluation, layout and PDF export.

A plain invoice (`zugferd: none`) must not run e-invoice code at all: the e-invoice modules are only loaded when `zugferd` is set. An e-invoice loads the modules that only some invoices need (`LAZY_MODULES` and `LAZY_CALLS` of `gate.py`: the checked writer of the guard, the messages of failed checks, `registry.json`, ...) only when it needs them; the benchmark invoices are valid and have no warnings, so the gate fails when their compile loads one of them.

Where the time goes is measured in the [budget table](#budget-table) below.

## Scripts

| Script               | Purpose                                                                                                                                                                           |
| :------------------- | :-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `gen_bench.py`       | Writes the benchmark invoices `<kind>-<lines>-plain.typ` and `<kind>-<lines>-zf.typ` to `tools/perf/out/bench/` (ignored by git).                                                 |
| `measure.py`         | Compiles documents round-robin, prints medians and the e-invoice cost of each plain/zf pair, checks limits; `--instructions` counts instructions, `--watch` times a live preview. |
| `gate.py`            | The performance gate of CI (`scripts/perf-gate`, see `tests/TESTING.md`), including the check that the benchmark invoices load no module they do not need.                        |
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

`--watch` measures the live preview, as an editor runs it with `typst watch`: it starts `typst watch` on a copy of each document (a hidden file next to it), changes the price of the first item to a new value before each round, as someone typing it, and reads the recompile time Typst reports. The two documents of a pair recompile one after the other, so the median of the differences of the rounds is what the e-invoice adds to a recompile:

```bash
tools/perf/measure.py --watch --runs 21 tools/perf/out/bench/[br]-*.typ
```

A recompile reuses what the edit does not touch (Typst memoizes the evaluation and the layout, and parses a module only once), so it takes less time than a cold compile; on a shared machine, its time varies by about 10 %.

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

Smaller effects show in the number of instructions a compile executes, which with `--jobs 1` is reproducible to a few thousand (with parallel jobs it varies by about 0.05 %). `measure.py --instructions` compiles each document once with `valgrind --tool=cachegrind` (on the `PATH`), `typst compile --jobs 1` and a fixed creation timestamp, and prints the counts in millions and, for each plain/zf pair, the instructions the e-invoice adds; `--jobs N` counts N documents at a time:

```bash
tools/perf/measure.py --instructions --jobs 2 tools/perf/out/bench/b-5-*.typ
# the same documents in a checkout of the commit before, for an A/B comparison
tools/perf/measure.py --instructions --jobs 2 --root /tmp/base /tmp/base/tools/perf/out/bench/b-5-*.typ
```

The count of the zf invoice minus that of the plain invoice is the work the e-invoice adds: the e-invoice path and embedding the XML in the PDF. A comment or an unused binding moves the count by less than 0.1 M, but other small changes can move it by a few hundred thousand instructions for reasons outside the change (removing six comment lines from the body of `invoice` measured +0.26 M), so treat differences below about 0.5 M at 5 lines with care. Instructions miss what the CPU waits for (page faults, cache misses), so confirm a change with a trace as well.

## Budget table

Measured on a shared virtual machine with 4 cores and typst 0.14.2, before (8d5b259) and after the second pass over the fixed costs of the e-invoice path, on the benchmark invoices of `gen_bench.py`.

Instructions executed (millions, `measure.py --instructions`, see [above](#measuring-small-changes)); the e-invoice path is the compile with e-invoice minus the plain one:

| Invoice                      |         5 lines |         50 lines |        300 lines |
| :--------------------------- | --------------: | ---------------: | ---------------: |
| `b`: plain compile           |           1 134 |            3 176 |           14 520 |
| `b`: e-invoice path          |   137.3 → 125.4 |    252.2 → 227.1 |    880.9 → 786.8 |
| `r`: plain compile           |           1 296 |            3 600 |           16 361 |
| `r`: e-invoice path          |   154.6 → 141.5 |    284.4 → 260.2 |  1 024.2 → 938.8 |
| Change of the e-invoice path | −8.7 % / −8.5 % | −10.0 % / −8.5 % | −10.7 % / −8.3 % |

The plain compiles changed by −0.9 M (`b`) and −0.7 M (`r`) instructions at 5 lines, −9 M (`r`) at 300 lines, and less than 0.01 % otherwise. The IBAN and BIC helpers (`utils/iban.typ`, `utils/bic.typ`) then stopped compiling a whitespace pattern, which saved about 2 M instructions more on every compile at 5 lines, with or without e-invoice (plain: −2.2 M `b`, −1.9 M `r`), and leaves the e-invoice path as it is.

What each change saved at 5 lines (`b-5`, e-invoice path, each against the commit before it):

| Change                                                                                                      | Instructions |
| :---------------------------------------------------------------------------------------------------------- | -----------: |
| The serializer writes a valid document in one pass; its checked writer (`guard/rare.typ`) runs for others   |       −6.1 M |
| `invoice` passes its subject to the e-invoice only when the subject can name another type of document       |       −0.5 M |
| `plain-text` takes strings and simple content the short way and collapses whitespace without a pattern      |       −0.9 M |
| The code lists are JSON (`guard/lists.json`)                                                                |       −3.7 M |
| The warnings of a fallback of `zugferd: auto` and the diagnostics of a self-billed invoice load when needed |       −1.0 M |

Where the rest goes at 5 lines (`b-5`, 125 M instructions): loading the modules takes about 66 M. Parsing and preparing them costs about 530 instructions per byte of code and 90 per byte of comments; `guard/write.typ` (25 KiB) takes 9.9 M, of which 1.4 M compile its three patterns and 1.0 M read its comments. No benchmark invoice leaves more than about 2 KiB of the code of any module uncalled (`model.typ` 2.0, `rules/engine.typ` 1.9, `build.typ` 1.2 KiB), so splitting the large modules would save little: the import is the size of the code an e-invoice runs. `process-zugferd` takes about 60 M, of which about 13 M hash the closures it reaches at their first call (see rule 9 below): 10.4 M at the call of `process-zugferd` (4.1 M for what `build-model` reaches, 4.3 M for `run-rules`, 1.6 M for `build-tree`), 1.8 M at the first call of the serializer's `write` and about 1 M at that of its `element`, which captures the table of the profile.

The perf gate (`scripts/perf-gate --runs 5`), run alternately on both commits:

| Gate metric (median of 4 runs of the gate each) | 5 lines         | 50 lines       | 300 lines        |
| :---------------------------------------------- | :-------------- | :------------- | :--------------- |
| Share of the plain compile                      | 16.1 % → 15.2 % | 8.8 % → 7.9 %  | 5.6 % → 5.0 %    |
| E-invoice path                                  | 38.9 → 36.3 ms  | 68.6 → 60.3 ms | 213.2 → 183.2 ms |
| Module import (budget 12 ms)                    | 18.9 → 17.2 ms  | 17.8 → 16.6 ms | 18.4 → 16.3 ms   |
| Serializer per line (budget 0.5 ms)             | 1.84 → 1.65 ms  | 0.54 → 0.47 ms | 0.36 → 0.29 ms   |

The single runs of the gate gave shares of 15.0 to 16.6 % (before) and 14.3 to 15.7 % (after) at 5 lines, where the plain compile took 230 to 265 ms; the gate stays yellow at 5 lines, for the share and the module import. An earlier gate run on the same commit measured 18.4 % (43.2 ms of 234.8 ms): the load of the shared machine moves the medians by several milliseconds, so compare checkouts in runs one after the other, as here.

Loading the modules of the serializer, before and after (KiB): `guard/write.typ` 31.2 → 24.8 (its checked writer moved to `guard/rare.typ`, 6.3 → 25.5, which a valid invoice does not load), `guard/lists.typ` 21.5 → 2.0 plus `guard/lists.json` (23.1, which Typst reads natively: 2.1 M instead of 5.9 M instructions), `zugferd.typ` 5.5 → 3.7 (plus `rare.typ`, 2.5, loaded when needed).

The first pass (6125e79 → 7a631be) cut the e-invoice path from 196.6 to 162.7 M instructions at 5 lines: the guard tables became JSON (0.8 ms to load instead of 2.4 ms), the elements that occur once no longer had a memoized check of their structure, and the modules of rare cases loaded only when needed.

### Live preview

The maintainer accepts an e-invoice share above 15 % at 5 lines as long as the live preview stays comfortable. A preview (`typst watch`, the preview of an editor) recompiles the document after each edit and reuses what the edit leaves alone: the parsed modules and the results of the calls whose inputs stay the same, such as the lines of the invoice that did not change. `measure.py --watch --runs 21` changed the price of the first item before each recompile. The times are medians of 21 recompiles, as ranges over the runs on the shared machine (one at 300 lines, two to six otherwise); the instructions are those of one recompile (cachegrind on `typst watch --jobs 1`, three edits against none):

| Invoice        | Recompile without e-invoice | Recompile with e-invoice | Instructions per recompile, without → with |
| :------------- | --------------------------: | -----------------------: | -----------------------------------------: |
| `b`, 5 lines   |                  105–111 ms |               114–118 ms |                                531 → 550 M |
| `r`, 5 lines   |                  122–132 ms |               135–142 ms |                                596 → 625 M |
| `b`, 50 lines  |                  317–337 ms |               326–338 ms |                            1 480 → 1 528 M |
| `r`, 50 lines  |                  345–381 ms |               366–415 ms |                            1 663 → 1 725 M |
| `b`, 300 lines |                      1.73 s |                   1.79 s |                                          – |
| `r`, 300 lines |                      2.10 s |                   2.10 s |                                          – |

After an edit, the preview of an e-invoice with 5 lines is up to date in about an eighth of a second, some 10 ms later than without e-invoice: the e-invoice adds 19 to 29 M instructions (3 to 5 %) to a recompile, while it adds 125 to 142 M (11 %) to a cold compile. At 50 lines it adds 3 to 4 %, less than the times vary between runs; at 300 lines, the invoice itself takes about 2 s per recompile.

## Keeping the e-invoice path cheap

These rules come from measurements of the e-invoice path. They apply to all code that runs for every invoice or for every line. Instruction counts are from `cachegrind` (see above); on the test machine, the e-invoice path executes about 4 000 instructions per microsecond.

1. Compile regular expressions once at module level, never inside a function: `regex(..)` costs 0.05 to 0.4 ms per call. Prefer a string method where one does the job: a class of all Unicode characters of a kind, such as `\s`, takes about 1 M instructions to compile, which a module pays for every compile that loads it, while `split()` splits at the same whitespace (`normalize-iban`, `plain-text`).
2. A function called per line gets the line (and small flags), never the whole model or `ctx`. Typst hashes the arguments of every closure call to memoize it; for a 300-line model that is about 70 µs per call.
3. Use `for` loops instead of `.map(..)`, `.filter(..)` or `.find(..)` with a closure in code that runs per line or per element (a few µs per closure call, plus hashing).
4. Look codes up in a dictionary (a hash lookup, about 500 instructions) or in a string of codes between spaces (`" " + code + " " in list`, about 6 000 instructions in a list of 2 000 codes), never in an array (about 60 000). A dictionary costs about 4 400 instructions per code to build when its module loads, a string little more than reading it; the code lists that every e-invoice loads are strings for that reason (`guard/lists.json`, whose lines of codes `guard/lists.typ` joins).
5. Call `process-zugferd` once per compile, outside of `context` and outside of loom's measure pass.
6. Bound every iterative walk per line: Typst stops a `while` loop after 10 000 iterations, which a loop over all elements of a large invoice reaches.
7. Load the e-invoice modules only when `zugferd` is set.
8. Count calls in code that runs per element or per line. A call of a function or method (e.g. `type(..)`, `.at(..)`) costs 4 000 to 5 500 instructions, as does a call of a closure whose result Typst has memoized; an operator, a field access or `in` costs about 500, a `let` in a loop body about 2 400, destructuring about 1 300 per name. Prefer operators and fields, and leave out bookkeeping that can be derived: the serializer tells that an element wrote no child from the index of the last child written, without a counter.
9. At the first call of a closure in a compile, Typst hashes the closure with its syntax tree and everything it captures, closures and modules included; the arguments, deeply, at every call. Large constant data (tables, lists) belongs in values a function captures or loads, not in its arguments; a call on small arguments (an index, a string) is cheap to memoize. A module a function refers to is hashed with the function: `invoice` referring to the module of the languages cost every compile 0.5 M instructions, so the helper that needs the languages imports the module in its body.
10. Every module the e-invoice path loads costs its size (see the budget table), and the closures a call reaches cost hashing once. Code that only some invoices need goes into a module of its own, imported in the function that needs it (`import "rare.typ": skipped-warnings` in the function body): Typst parses the module only when the import runs (`rare.typ`, `guard/rare.typ`, `keys.typ`, `units.typ`, `report.typ`, the messages of the rules). The perf gate fails when a benchmark invoice loads one of them (`LAZY_MODULES` of `gate.py`).
11. Generated data that the code only reads is JSON, read with `json(..)`: Typst reads it several times faster than the same data as a module (the XRechnung guard table: 0.8 ms instead of 2.4 ms; the code lists: 2.1 M instructions instead of 5.9 M).
12. Test the common case first, with one cheap check: most texts of an invoice are plain ASCII, which one regular expression tells (`plain-ascii` of `utils/text.typ`), so that the replacements of `plain-text` run only for the others; most amounts are decimals already (`type(value) == decimal`), so they are not converted again.
13. Write the common case in one pass that gives up at the first problem, and leave the reporting to a complete path that loads only then: the serializer writes a valid document without collecting findings and hands any other to its checked writer (`guard/rare.typ`), which writes the same XML and reports every finding. Both must agree on every input; the tests of the guard and criterion C0 of the mutation test compare them.
