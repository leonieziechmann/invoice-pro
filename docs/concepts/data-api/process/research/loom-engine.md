# Research: The loom engine and where the time goes

Phase-1 reader `loom-engine` of the data-API exploration (2026-11-02). Facts marked [v] were verified (read or run), [i] are inferences. `<repo>` is the repository root, `<session>` the scratch directory of the exploration (not part of the repository).

## Summary

The cost of loom in invoice-pro comes almost entirely from the N per-item motifs. The number of passes matters much less. weave(max-passes: 2) runs exactly one measure pass and one draw pass, and no convergence check ever runs (loom runtime.typ:70,86). Every pass runs scope+measure of every component again, and only the last pass draws (engine.typ:89-126). The second pass exists only so that siblings of line-items (payment-terms, bank-details EPC amount, paid/direct-debit, the payment-means sentence, dynamic totals) can read root's totals through `ctx.global`, which the injector puts in (invoice.typ:620-627). Measured with typst 0.15.1, traced medians of 5 runs. At 300 lines weave is 58 % of the compile (3.4 of 5.9 s). Of that, 72 % is the 300 item motifs (2×300 calls). About 3 ms per item per pass goes into the item scope: roughly 20 loom.mutator ops, each a memoized closure call whose argument (state = full ctx) Typst hashes. Prototype P1 supplies the precomputed `global` and runs max-passes: 1. The PDFs are byte-identical in all 24 configs, but it saves only 20-28 % wall time at 300 lines, because the remaining draw pass loses the memo hits it used to get from pass 1. Prototype P2 replaces the N item motifs with ONE raw motif that emits the same N 'item' frames, computed by a pure function of (rows, small settings). It saves 40-50 % wall time at 300 lines, about 30 % at 50 and 0-16 % at 5, again byte-identical. With P2 the second pass costs almost nothing, because Typst's closure memoization serves the repeated computation. P3 (P2 plus a single pass) is therefore within noise of P2. The totals can also be computed exactly in plain Typst before weave, from data only, with the package's own logic functions (P4: exact for basic and rich invoices; about 0.1 s traced at 300 lines). So a single pass is possible, but only worth it as a secondary opt-in. Bulk data must not travel unsealed in the loom ctx: a 300-row dict in ctx adds 2.2 s (+38 %); sealed in metadata it adds nothing. The rest of the cost is outside loom: Typst layout (2.1 s at 300 lines, 3 layout iterations), module import (about 135 ms fixed), the EPC-QR wasm (about 40 ms fixed) and zugferd. Side findings: weave's `observer` path in loom 0.1.1 is broken (typo `interwine`). `typst query` is deprecated in 0.15.1 in favour of `typst eval ... --in`, which 0.14.2 lacks.

## Key facts

- [v] weave runs (max-passes - 1) measure passes plus one draw pass; with max-passes: 2 that is exactly 1 measure + 1 draw; the convergence check needs i > 0, so it never runs with max-passes 2; handle-nonconvergence only fires if measure-limit > 1 (<loom>/src/core/runtime.typ:70 (measure-limit), :73-98 (loop), :86 (`if i > 0 and new-payload == current-payload`), :93 (nonconvergence), :100-110 (draw))
- [v] intertwine runs scope -> recursion into body -> measure on EVERY pass and calls draw only on the draw pass; containers and wrappers are traversed every pass and rebuilt via (node.func())(..fields) on the draw pass (loom src/core/engine.typ:84-129 (component: scope :89, body :94-99, measure :111, draw :122-126), :132-169 (container), :172-198 (wrapper), :201-223 (generic child), :226 (atomic))
- [v] The injector merges a dict into ctx on each pass; the payload is the previous pass's normalized root frames (starts as `()`). invoice-pro maps it to ctx.global = root's public signal (total, formated-total, bank, payment-means) (runtime.typ:75-76,101-103; src/invoice.typ:620-627; src/components/root.typ:285-290)
- [v] The second pass is needed only by siblings of line-items that read ctx.global in measure/draw: payment-terms (total), bank-details (EPC-QR amount), paid/direct-debit/card (total), payment-means kinds via of-context (payment sentence, QR default), payment-reference (global.bank), dynamic('total', ..). The page frame and line-items get same-pass values because root.draw overrides ctx.global with its own view (src/components/payment-terms.typ:94; src/components/bank-details.typ:212-217; src/components/payment-means.typ:285; src/logic/payment-means.typ:142-155; src/logic/payment-reference.typ:61-63; src/components/dynamic.typ:248-262; src/components/root.typ:442-456; src/theming/frame.typ:111-112)
- [v] 2 passes are output-stable but not a strict fixed point: with max-passes 3 the payload differs between pass 1 and pass 2 in global.bank.payment-amount (0 in pass 1) and payment-means; max-passes 4 converges at the 3rd measure pass; all three give byte-identical PDFs (exp/loom-engine/ip-conv (handle-nonconvergence emitting metadata) + conv-r5.typ: typst query <ip-nonconv> -> [{iterations:2, differing-keys:[bank,payment-means], bank-diff:[payment-amount]}] for max-passes 3, [] for 4; md5 2227f719c19d for 2/3/4)
- [v] The injected global is pure data (decimals, strings, none, arrays, dicts; no content) and round-trips via repr()/eval (typst query --input ip-dump-global=1 p1/v2p-_.typ <ip-global> -> p1/g-_.typ; used as `global:` input, outputs identical)
- [v] P1: weave(max-passes: 1, injector: ctx + (global: precomputed)) gives byte-identical PDFs for b/r x 5/50/300 x plain/zf on typst 0.15.1 and 0.14.2 (exp/loom-engine/sumwall.py on results-wall.json: all 24 configs '=' (md5 equal to base))
- [v] P2: one raw motif `item-rows(rows)` that returns an array of N frames of kind 'item' (computed by a memoizable pure function compute-rows(rows, settings)) gives byte-identical PDFs (incl. ZUGFeRD XML) to N item() motifs (exp/loom-engine/ip-var/components/item-rows.typ; sumwall.py: all 24 configs '=')
- [v] Per-item motif cost dominates weave: at 300 lines (0.15.1 traced median) item motifs are 1280 ms (measure pass) + 1167 ms (draw pass) = 72 % of weave 3412 ms; item scope alone 894 + 888 ms (~3 ms/item/pass) (results-baseline-trace.json via summarize.trace_table: 015-b-300-plain M|item.typ excl 1279.9 scope 893.6; D|item.typ excl 1167.3 scope 887.7)
- [v] The item scope is ~20 loom.mutator ops; each op is a closure call taking (state with base = full ctx, read = \_read.with(state)); Typst memoizes closure calls by hashing the arguments, so every op hashes the ctx (src/components/item.typ:200-293; loom src/lib/mutator.typ:37-62 (batch loop :55-57); trace drill-down (sub.py item.typ:200) shows ~20 mutator.typ:182/202/147 calls at 0.1-0.3 ms each; Typst docs: 'it memoizes the result of calling a closure with a certain set of parameters' https://github.com/typst/typst/blob/main/docs/dev/architecture.md; the repo's own note tools/perf/README.md rule 2/9)
- [v] Typst memoization makes the second pass cheap for any sub-call whose arguments do not change between passes: line-items measure costs 427 ms in the measure pass and 15 ms in the draw pass; component-level scope/measure miss the cache because ctx differs between passes (sys.pass, global) (015-b-300-plain: M|line-items measure 427.0 vs D|line-items measure 14.6; runtime.typ:74,101 set sys.pass)
- [v] Totals can be computed exactly in plain Typst before weave from data alone (rows + document modifier/prepayment content) with calculate-item-data, calculate-modifier and calculate-taxes; this matches the measure pass for b and r at 5 and 300 lines (exp/loom-engine/p4/precompute-lib.typ + p4/pc-{r-300-zf,b-300-plain,r-5-zf}.typ: ok-total true, ok-fmt true; trace: precompute 94-136 ms at 300 lines, 23 ms at 5)
- [v] Putting a 300-row data dict unsealed into the loom ctx (via weave inputs) costs +2.16 s (+38 %) with per-item motifs and +0.29 s with item-rows; sealed in metadata (like the theme) it costs ~0 (results-p5-wall.json (typst 0.15.1, median of 5): items-300 none 5.69 s / open 7.86 s / sealed 5.82 s; rows-300 none 2.97 / open 3.26 / sealed 3.06; seal mechanism src/theming/access.typ:1-11)
- [v] loom's prebuilt `static` motif keeps its content out of traversal (the body is captured in the draw closure, and the motif's own body is none); wrapping 120 styled static blocks saved ~0.1-0.16 s with an identical PDF. invoice-pro's wrapper does not re-export it (loom src/lib/motifs.typ:121-130; src/loom-wrapper.typ:16-22; results-p5-wall.json s-no 0.784 s vs s-yes 0.623 s, md5 e3bcc79df2 both)
- [v] loom 0.1.1 weave(observer: ..) crashes: runtime calls engine.interwine (typo) (runtime.typ:117; exp/loom-engine/obs.typ -> 'error: module `engine` does not contain `interwine`')
- [v] A raw motif's measure may return an array of frames; engine normalize flattens it into the parent's children list; invoice-pro's applicators already do this (loom src/data/frame.typ:120-143 (normalize); src/logic/modifier-applicator.typ:257-276; src/logic/tax-applicator.typ:163-177)
- [v] typst 0.15.1 deprecates `typst query` (warning, hint: `typst eval 'query(<o>).first().value' --in file`); typst 0.14.2 has no `eval` subcommand; json(bytes(sys.inputs.x)) and json(path-from-input) work in both (exp/loom-engine/inp.typ runs on both binaries)
- [v] Fixed costs at 5 lines (0.15.1 traced): import ~137 ms (32 %), weave 165 ms of which line-items part draw ~44 ms and bank-details part draw ~39 ms (the EPC-QR via the rustycure wasm plugin), layout ~64 ms (2 iterations), pdf ~8 ms (results-baseline-trace.json 015-b-5-plain)
- [v] Typst layout is the second-largest cost and lies outside loom: 2.1 s of 5.9 s at 300 lines (3 layout iterations at >= 50 lines, 2 at 5 lines) (results-baseline-trace.json 015-b-300-plain layout 2102.5, iters 3)

## Implications

- Data format and hydration must NOT expand data rows into N `item()` motifs. Feed the list as ONE motif (e.g. item-rows(rows) or line-items(data: rows)) that emits the same 'item' frames. This keeps line-items, the applicators, resolve-tree and zugferd unchanged (API extension only), gives byte-identical output, and is the largest available speed win: wall time -40..50 % at 300 lines, about -30 % at 50, about 0-16 % at 5.
- Row computation must be a pure function of (rows, small settings) and must never take the ctx. Then Typst's closure memo cache serves loom's second pass almost for free. settings-of(ctx) must leave out pass-varying keys (sys, global).
- Row values should be plain data so they stay memoizable and JSON/CLI-friendly: money and quantities as strings (decimal exactness; JSON numbers arrive as int/float), units as codes or keys (mapped to the unit module), tax as a dict or rate, modifiers as dicts (content modifiers such as discount([..]) need ctx plus an intertwine per row and are not memoizable).
- Never put bulk data (items, large custom-field dicts) unsealed into the loom ctx (weave inputs): every closure call hashes the ctx, which measured +38 % at 300 lines. Use motif arguments, or seal in metadata(...) the way the theme is sealed (theming/access.typ). Custom fields in ctx should be small, or sealed and unsealed on read.
- Skipping the measure pass (max-passes: 1) is possible and output-identical when `global` = (total, formated-total, bank, payment-means) is known up front. All four are pure data, and the totals can be computed exactly in plain Typst before weave from data. But once the data path is used (P2) it saves only ~0-5 % more. Treat it as an optional fast path (e.g. when the data carries all totals-relevant inputs), not a requirement of the format. If offered, root.draw can cheaply check the injected global against its own same-pass view.total (root's measure runs in the draw pass anyway) and report a mismatch.
- A single pass couples the format to the skeleton: anything in the skeleton that affects totals (line-items(tax:/tax-mode:), group/apply cascades, document discounts/surcharges/prepayments placed in the skeleton, bank-details for payment-means) must either be in the data or be reproduced by the precompute. The 2-pass + memo approach has no such coupling and is equally fast.
- Conditional or custom content (e.g. a coat of arms (Wappen) by postal code) fits the existing draw-only `dynamic(ctx => ..)` content motif (one closure call per draw pass; it can read ctx.global totals), or plain Typst in the skeleton outside loom. Large static design content in the skeleton could be wrapped in loom's `static` motif to skip traversal and rebuilding (would need a re-export, i.e. an API extension).
- Phase-1 CLI: data via `--input data='<json>'` -> json(bytes(sys.inputs.data)), or `--input data-file=path` -> json(path); both work on 0.14.2 and 0.15.1. For machine-readable output (e.g. computed totals for phase-2 bindings), metadata + `typst query` works on both versions, but query is deprecated in 0.15.1 (`typst eval ... --in` is 0.15+ only). The `global` record is already a natural candidate (pure data, round-trips via repr).
- After P2, the remaining loom hot spots are internal and need no API change: line-items' per-item format-item via loom.mutator.batch (~350-460 ms traced at 300 lines, first pass only) and modifier-applicator collect-signals (~60-120 ms). The bigger remaining costs (Typst layout 2-3 s at 300 lines, imports ~135 ms, EPC-QR ~40 ms, zugferd 30-230 ms) are outside loom.

## Risks

- Traces inflate closure-heavy code (a traced 300-line compile takes ~9-11 s vs ~6 s untraced), so trace shares are indicative. Decisions should rest on the untraced wall medians, which agree in direction.
- Shared 4-core VM: the baseline traced run overlapped with light prototype compiles (5-line), so single-run spreads of ±10-20 % occur. All variant comparisons were run round-robin (order alternating per round) and are medians of 5 runs (3 for the variant traces).
- P1/P3 correctness depends on a complete and correct `global` (incl. bank and payment-means). A stale or wrong precomputed value silently changes the payment sentence, the EPC-QR amount and paid/direct-debit texts. It needs a consistency check (root.draw compares with view.total) or should only be derived internally.
- The item-rows prototype differs from item() in internal frame keys/paths (('item', i) instead of ('item', relative-id)). It skips the assert-direct-parent guard, supports only flat rows (no group/bundle nesting from data) and resolves content modifiers with ctx. Output was identical for the benchmark kinds, but groups, bundles, apply cascades, small-business and notes/origin need dedicated tests (tytanic is not available here).
- Memoization wins assume the compute function's arguments are identical across passes. A future change that passes ctx (or a key holding `global`) into it would silently lose the speedup.
- The precompute (P4) re-implements the line-items/root aggregation path in plain Typst. Two code paths can drift unless they share one function (e.g. line-items' measure calls the same pure function).
- loom 0.1.1 has a broken `observer` path (typo), and the pass structure (sys.pass in ctx) cannot be changed without a loom release. The maintainer also authors loom, but upgrading loom is a dependency change.

## Open questions

- Expose a single-pass fast path at all (e.g. invoice(.., totals:) or automatic when all inputs are in data), or rely on bulk motif + memoization only? The measurements favour the latter: P3 ≈ P2.
- How should nested structure from data (groups with subtotals, bundles, per-group apply cascades) map onto bulk motifs: one item-rows per group inside group(..), or a nested row format that item-rows/resolve-tree understand directly?
- Should line-items accept data directly (line-items(rows: ..)) or should a separate item-rows/items component be added? Both are API extensions; the first keeps the skeleton's line-items call as the single place to design columns and options.
- Should loom get upstream improvements: a skip-measure mode when the injector declares completeness, keeping sys.pass/global out of the memo-relevant ctx (e.g. global sealed in metadata), fixing `interwine`?
- Should invoice-pro's loom-wrapper re-export `static` for heavy static skeleton content (API extension)?
- Should the internal line-items format-item path (loom.mutator.batch per item, ~1.2-1.5 ms/item traced in pass 1) be rewritten as plain dict construction as part of this feature?
- What drives the 3rd Typst layout iteration at >= 50 lines (frame introspection: invoice-span queries, page counters)? It is outside loom but is now the largest remaining cost.

## Measurements

- Baseline breakdown, typst 0.15.1, `typst compile --root . --timings`, median of 5 traced runs (exp/loom-engine/runner.py results-baseline-trace.json 5 trace ...; aggregated by agg.py), b-plain: 5 lines total 421 ms = imports 137 + pre-weave 37 (theme build ~23) + weave 165 (measure 48 / draw 116) + layout 64 (2 iter) + pdf 8; 50 lines total 1297 = imports 140 + weave 625 (330/307) + layout 379 (3 iter) + pdf 14; 300 lines total 5920 = imports 130 + weave 3412 (1916/1362) + layout 2103 (3 iter) + pdf 55.
- Weave share of total (0.15.1 traced, b-plain): 39 % (5), 48 % (50), 58 % (300). Item motifs' share of weave: 26 % (5), 67 % (50), 72 % (300).
- Per-component exclusive time, 0.15.1 traced, b-300-plain (measure pass | draw pass): item x300 1280 | 1167 (scope 894 | 888, measure 319 | 225); line-items 430 | 70 (measure 427 | 15: memo hits; draw = items-table part 52); modifier-applicator 119 | 38; root 18 | 20; tax-applicator 16 | 8; bank-details 2 | 40 (draw = EPC-QR); payment-terms 2 | 2.
- Fixed draw-pass costs at 5 lines (0.15.1 traced): line-items part 44 ms, bank-details part 39 ms (EPC-QR via @preview/rustycure ~39-40 ms), root draw ~1 ms (plain) / ~37 ms (zf, process-zugferd).
- Zugferd (outermost events in /src/zugferd/, 0.15.1 traced medians): b 29 / 54 / 184 ms at 5 / 50 / 300 lines; r 34 / 57 / 227 ms.
- typst 0.14.2 baseline (traced medians): b-plain total 398 / 1167 / 5953 ms, weave 121 / 558 / 3251 ms (measure 46 / 298 / 1960); r-300-zf total 7602, weave 3785. Layout ≈ 68 / 420 / 2475 ms, derived (0.14 names spans 'layout (n)'; the aggregator was fixed later).
- Untraced wall-clock medians of 5 round-robin runs (results-wall.json), typst 0.15.1, base -> P1 (1 pass + given global) / P2 (item-rows, 2 passes) / P3 (item-rows + 1 pass): b-5-plain 0.40 -> 0.41 / 0.37 / 0.38 s; b-5-zf 0.47 -> 0.41 / 0.43 / 0.45; r-5-zf 0.55 -> 0.47 / 0.46 / 0.45; b-50-plain 1.23 -> 1.11 / 0.81 / 0.83; r-50-zf 1.45 -> 1.18 / 0.93 / 0.98; b-300-plain 6.11 -> 4.41 (-28 %) / 3.07 (-50 %) / 3.01 (-51 %); b-300-zf 5.98 -> 4.75 / 3.19 / 3.19; r-300-plain 6.79 -> 5.31 / 3.92 / 4.04; r-300-zf 7.41 -> 5.69 (-23 %) / 4.41 (-40 %) / 4.30 (-42 %).
- Same on typst 0.14.2: b-300-plain 5.78 -> 4.47 / 3.34 / 3.20 s; r-300-zf 7.11 -> 5.85 / 4.35 / 4.28; b-50-plain 1.28 -> 1.11 / 0.89 / 0.88; b-5-plain 0.44 -> 0.42 / 0.46 / 0.38.
- Output identity: md5 of every variant PDF equals base for all 24 configs (b/r x 5/50/300 x plain/zf x 2 typst versions) x 3 variants (sumwall.py '=' everywhere). The zf PDFs embed the XML, so the e-invoice is identical too.
- Variant traces (0.15.1, median of 3) at b-300-plain: weave base 3412 -> P1 2071 (draw only; items now 1429 ms because pass-1 memo hits are gone) -> P2 874 (measure 709, draw 143) -> P3 833. r-300-zf: 3805 -> 2418 / 1328 / 1158.
- Convergence test (exp/loom-engine/ip-conv, conv-r5.typ, --input ip-max-passes=N): N=2 no check; N=3 nonconvergence in bank.payment-amount; N=4 converges; all md5 2227f719c19d.
- ctx-hashing test (results-p5-wall.json, 0.15.1, 5 runs): 300 rows as data in ctx: per-item motifs 5.69 s -> 7.86 s unsealed, 5.82 s sealed; item-rows 2.97 -> 3.26 unsealed, 3.06 sealed; 50 lines 1.26 -> 1.40 unsealed, 1.16 sealed.
- Static traversal test: b-5 + 120 styled static blocks: 0.784 s -> 0.623 s when wrapped in loom static motif (median of 5, identical md5).
- Precompute-before-weave (p4/precompute-lib.typ), traced single run: 136 ms (r-300), 94 ms (b-300), 23 ms (r-5); of which compute-rows 54-64 ms at 300 rows.

## Notes

### loom engine internals & performance (exploration notes)

All experiment files are under `<session>/exp/loom-engine/`. The repo is untouched (`git status` clean). Prototypes live in copies of `src/`:

- `ip-base/`: pristine copy, byte-identical output to the package.
- `ip-var/`: P1 `global:` param + dump hook, plus `components/item-rows.typ` (P2).
- `ip-conv/`: convergence probe.
- `ip-data/`: `data:` in ctx, for the hashing probe.

Tools:

- `tree.py`, `sub.py`: trace tree viewers.
- `agg.py`: loom-aware trace aggregator. Per pass, per component kind: scope, measure, draw and exclusive time.
- `runner.py`: round-robin runner (`trace` or `wall` mode).
- `summarize.py`, `sumwall.py`: medians.
- `results-*.json`: raw per-run data.

#### 1. How `weave` works (loom 0.1.1)

##### Construction

- `construct-loom(key)` (lib/factory.typ:36) binds every primitive to a label key. invoice-pro uses `<invoice-pro:0.6.0>` (src/loom-wrapper.typ:3).
- A component (motif) is `[#metadata((type: "component", scope, measure, draw, body))#key]` (data/primitives.typ:32-52).

##### `weave(key, injector, debug, inputs, handle-nonconvergence, max-passes: 2, observer, director)` (core/runtime.typ:30-128)

1. `base-ctx = empty-context + inputs`, with sys fields debug and key (:64-65). `empty-context = (sys: (path: (), debug: false, relative-id: 0))` (core/context.typ:26).
2. `measure-limit = max-passes - 1` if max-passes > 1, else 0 (:70). **max-passes counts the measure passes plus the final draw pass.**
3. Measure loop (:73-98), for each i:
   - ctx = base + `sys.pass = "measure"`, plus `injector(ctx, current-payload)` (payload starts as `()`).
   - `(_, new) = intertwine(ctx, director, draw: false)`.
   - Convergence check only when `i > 0` (:86).
   - `handle-nonconvergence` only on the last iteration, and only if measure-limit > 1 (:93).
4. Draw (:100-110): ctx = base + `sys.pass = "draw"` + injector(ctx, payload); `intertwine(draw: true)`.
5. `observer` (:112-127) is broken: it calls `engine.interwine` (typo). Verified: obs.typ fails with "module `engine` does not contain `interwine`".

So with **max-passes: 2**:

- pass 1 = measure, with `global = (:)`;
- pass 2 = draw, with `global` = pass-1 payload.
- No convergence check ever runs.

With **max-passes: 1** there is no measure pass; the injector is called once with payload `()`.

##### `intertwine(ctx, node, key, draw)` (core/engine.typ:66-227)

| case        | condition                                           | work                                                                                                                                                                                                                                                                |
| ----------- | --------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1 component | metadata labelled key, `type: "component"` (:31-50) | `child-ctx = scope(ctx)`; `sys.relative-id = 0`; recurse into body; filter none; `(public, view) = measure(child-ctx, children)`; [debug: frame sys += children]; `draw(child-ctx, public, view, body-content)` only if draw; return `(content, normalize(public))` |
| 2 container | `has("children")`                                   | map children with relative-id = i; flatten data; on draw rebuild `(node.func())(..fields, ..children)` (sequence: join)                                                                                                                                             |
| 3 wrapper   | `has("body")`                                       | recurse, rebuild with positional fix-ups (alignment/angle/dest/count)                                                                                                                                                                                               |
| 4 generic   | `has("child")`                                      | recurse, rebuild                                                                                                                                                                                                                                                    |
| 5 atomic    | else                                                | node on draw, else none                                                                                                                                                                                                                                             |

**scope and measure run on every pass; only draw is draw-pass-only.** Static content is traversed on every pass and rebuilt on the draw pass.

##### Signals

- A component's `public` is normalized into a flat array of frames (data/frame.typ:120-143). A frame is `(type: "frame", kind, key, path, signal, sys)` (frame.typ:27-53).
- `managed-motif(name)` appends `(name, relative-id)` to `sys.path` in scope and wraps public into a frame with kind = name (primitives.typ:132-198).
- `data-motif` = `compute-motif(name: ..)` → managed (:206-282).
- `content-motif` passes its children's frames through (:290-328).
- A raw `motif` must return frames itself and **may return an array of frames**, which are flattened into the parent's children. invoice-pro's applicators use this (logic/modifier-applicator.typ:257-276, logic/tax-applicator.typ:163-177).

##### invoice-pro's tree and data flow

- Tree: `root` (managed, components/root.typ:108) > body: `line-items` (managed) > `tax-applicator(modifier-applicator(body))` (line-items.typ:721-724) > item / modifier / prepayment / group / bundle; plus siblings payment-terms, bank-details, etc.
- Injector (invoice.typ:623-625): `ctx + (global: payload.first().signal)`.
- Root public (root.typ:285-290): `(total: (net, gross, due, prepaid), formated-total, bank, payment-means)`.
- Pass 1: root.scope ensures zero totals (root.typ:172-187), and so do payment-terms.typ:74-79, bank-details.typ:156-160 and payment-means.typ:20-29.

**Why a 2nd pass is needed (consumers of ctx.global):**

- payment-terms.typ:94: amount in the payment sentence.
- bank-details.typ:212-217: EPC-QR amount.
- payment-means.typ:285: paid / direct-debit / card text amount.
- logic/payment-means.typ:142-155 `of-context`: payment sentence kind, QR display default (`transfer-requested`).
- logic/payment-reference.typ:61-63: `global.bank`.
- dynamic.typ:248-262: `dynamic("total", "gross")`.
- Not needed by the frame/page parts: theming/frame.typ:111 reads `ctx.global`, but root.draw replaces it with the same-pass `view.total` (root.typ:442-456).

**Convergence (verified):**

- max-passes 3: nonconvergence. The payload differs between pass 1 and pass 2 in `bank.payment-amount` (0 in pass 1, because bank-details' public carries the amount it computed from the zero totals) and in `payment-means` (contains the bank signals).
- max-passes 4: converges at measure pass 3.
- All give md5-identical PDFs. Nothing prints `global.bank.payment-amount`, so 2 passes are output-stable.

**When pass 1 could be skipped:** when the injector can give the same `global` without measuring. `global` is pure data (repr example in p1/g-r-5-zf.typ: decimals and strings). P1 proves this is output-identical.

#### 2. Cost model (measured)

##### Where the time goes — typst 0.15.1, traced medians of 5 (ms)

| config      | total | imports | pre-weave | weave | measure | draw | layout (iters) | pdf | zugferd |
| ----------- | ----- | ------- | --------- | ----- | ------- | ---- | -------------- | --- | ------- |
| b-5-plain   | 421   | 137     | 37        | 165   | 48      | 116  | 64 (2)         | 8   | 0       |
| b-5-zf      | 506   | 160     | 47        | 215   | 63      | 152  | 66 (2)         | 9   | 29      |
| b-50-plain  | 1297  | 140     | 35        | 625   | 330     | 307  | 379 (3)        | 14  | 0       |
| b-50-zf     | 1374  | 161     | 37        | 724   | 309     | 377  | 386 (3)        | 13  | 54      |
| b-300-plain | 5920  | 130     | 38        | 3412  | 1916    | 1362 | 2103 (3)       | 55  | 0       |
| b-300-zf    | 6081  | 133     | 33        | 3558  | 2013    | 1545 | 2145 (3)       | 55  | 184     |
| r-5-zf      | 545   | 131     | 36        | 233   | 67      | 169  | 98 (2)         | 10  | 34      |
| r-50-zf     | 1452  | 125     | 36        | 761   | 366     | 408  | 480 (3)        | 17  | 57      |
| r-300-plain | 7274  | 146     | 35        | 4027  | 2338    | 1507 | 3012 (3)       | 62  | 0       |
| r-300-zf    | 7471  | 127     | 39        | 3805  | 2118    | 1607 | 3100 (3)       | 64  | 227     |

typst 0.14.2 is similar: b-plain weave 121 / 558 / 3251 ms; totals 398 / 1167 / 5953 ms. Its traces name layout spans `layout (n)` (fixed in agg.py afterwards; the 0.14 layout figures are derived as ≈ total − imports − invoice() − pdf: 68 / 420 / 2475 ms). In the 0.14 traces the measure/draw split per component is shifted by one child span, so for 0.14 only the excl and scope columns are reliable.

##### Per component, 0.15.1 traced medians, b-300-plain (exclusive ms: measure pass | draw pass)

| component           | n   | excl         | scope      | measure              | draw                             |
| ------------------- | --- | ------------ | ---------- | -------------------- | -------------------------------- |
| item.typ            | 300 | 1280 \| 1167 | 894 \| 888 | 319 \| 225           | 0 \| 7                           |
| line-items          | 1   | 430 \| 70    | 1 \| 1     | 427 \| **15** (memo) | – \| 52 (table part)             |
| modifier-applicator | 1   | 119 \| 38    |            | 59 \| 5              |                                  |
| root                | 1   | 18 \| 20     | 3 \| 2     | 11 \| 7              | – \| 6                           |
| tax-applicator      | 1   | 16 \| 8      |            |                      |                                  |
| bank-details        | 1   | 2 \| 40      |            |                      | – \| 39 (EPC-QR, rustycure wasm) |
| payment-terms       | 1   | 2 \| 2       |            |                      |                                  |

At 5 lines (b-5-plain):

- draw pass: line-items part 44, bank-details part 39 (QR), items 18;
- measure pass: items 24 (scope 17), line-items 10.

r-300-zf adds:

- 62 modifier motifs (~103 | 90 ms);
- root draw 236 ms (`process-zugferd`).

**Per line (0.15.1 traced, 50 → 300):** weave ≈ 11.1 ms/line (item motif ≈ 4.3 ms measure + 3.9 ms draw; item scope ≈ 3 ms/pass); layout ≈ 6.9 ms/line. Wall clock (untraced): ≈ 19.5 ms/line total (base), ≈ 9 ms/line with P2.

**Why item scope is expensive:** item.typ:200-293 runs ~20 `loom.mutator` ops (derive/put/update/nest). Each op is `op(state, _read.with(state))` with `state.base` = the full ctx (mutator.typ:55-57). Typst memoizes every closure call by hashing its arguments (typst architecture.md; repo tools/perf/README.md rules 2 and 9). The ctx carries:

- locale ≈ 253 leaves (measured with leaves.typ);
- parties, references, validation issues;
- the theme, already sealed in metadata to avoid exactly this cost (theming/access.typ:1-11).

#### 3. Opportunities for a data-driven path — prototypes

All prototypes produced md5-identical PDFs (ZUGFeRD XML included, since it is attached in the PDF) for b/r × 5/50/300 × plain/zf on both typst versions.

- **P1 = one pass with a given global.** `invoice(global: G)` → `weave(max-passes: 1, injector: (ctx, _) => ctx + (global: G))`. G was dumped from pass 1 via `--input ip-dump-global=1` + `typst query <ip-global>` (repr) and re-imported as a `.typ` module (p1/g-\*.typ).
- **P2 = `item-rows(rows)`.** One raw motif. Its measure:
  - resolves content modifiers with ctx (rare);
  - calls `compute-rows(rows, settings-of(ctx))`: a pure function of data plus small settings (the item scope's cascade: quantity/unit/tax/tax-mode/input-gross/…, row style, locale), with a unit-resolution cache;
  - each row: `calculate-item-data(lite-ctx, name)`;
  - emits N frames `frame.new(kind: "item", key: ("item", i), path: base + (("item", i),), signal)`.

  line-items, the applicators, resolve-tree and zugferd are unchanged. File: ip-var/components/item-rows.typ.

- **P3 = P2 + P1.**
- **P4 = totals computed in plain Typst before weave** (p4/precompute-lib.typ). It uses `compute-rows`, `calculate-modifier`, `calculate-taxes`, prepayment normalization and `format.currency`. Document modifiers and prepayments get their signals from one tiny `loom.core.intertwine` of their content. Result: `pc.total == g.total` and `pc.formated-total == g.formated-total` for r-300-zf, b-300-plain and r-5-zf. Cost: 94-136 ms traced at 300 lines, 23 ms at 5.

##### Wall clock, untraced, median of 5 round-robin runs (s)

| config      | 0.15 base | P1   | P2   | P3   | 0.14 base | P1   | P2   | P3   |
| ----------- | --------- | ---- | ---- | ---- | --------- | ---- | ---- | ---- |
| b-5-plain   | 0.40      | 0.41 | 0.37 | 0.38 | 0.44      | 0.42 | 0.46 | 0.38 |
| b-5-zf      | 0.47      | 0.41 | 0.43 | 0.45 | 0.49      | 0.47 | 0.45 | 0.45 |
| r-5-plain   | 0.49      | 0.42 | 0.46 | 0.44 | 0.50      | 0.49 | 0.49 | 0.44 |
| r-5-zf      | 0.55      | 0.47 | 0.46 | 0.45 | 0.54      | 0.50 | 0.47 | 0.47 |
| b-50-plain  | 1.23      | 1.11 | 0.81 | 0.83 | 1.28      | 1.11 | 0.89 | 0.88 |
| b-50-zf     | 1.26      | 1.13 | 0.88 | 0.87 | 1.31      | 1.17 | 0.95 | 0.90 |
| r-50-plain  | 1.37      | 1.16 | 0.96 | 0.95 | 1.43      | 1.22 | 0.96 | 1.01 |
| r-50-zf     | 1.45      | 1.18 | 0.93 | 0.98 | 1.44      | 1.29 | 1.02 | 0.99 |
| b-300-plain | 6.11      | 4.41 | 3.07 | 3.01 | 5.78      | 4.47 | 3.34 | 3.20 |
| b-300-zf    | 5.98      | 4.75 | 3.19 | 3.19 | 5.68      | 4.51 | 3.18 | 3.26 |
| r-300-plain | 6.79      | 5.31 | 3.92 | 4.04 | 6.68      | 5.39 | 4.15 | 4.16 |
| r-300-zf    | 7.41      | 5.69 | 4.41 | 4.30 | 7.11      | 5.85 | 4.35 | 4.28 |

##### Traced weave (0.15.1, median of 3): base → P1 / P2 / P3 (ms)

| config      | base | P1   | P2                           | P3   |
| ----------- | ---- | ---- | ---------------------------- | ---- |
| b-5-plain   | 165  | 160  | 122                          | 124  |
| b-50-plain  | 625  | 438  | 244                          | 212  |
| b-300-plain | 3412 | 2071 | 874 (measure 709 / draw 143) | 833  |
| r-300-zf    | 3805 | 2418 | 1328                         | 1158 |

**Why P1 helps less than "half":** in the baseline, the draw pass gets memo hits from pass 1 (line-items measure 427 → 15 ms). With one pass, everything is cold: draw-only items cost 1429 ms vs 1167 ms in the baseline draw pass.

**Why P3 ≈ P2:** `compute-rows(rows, settings)` has identical arguments on both passes, so the second pass is a memo cache hit. The P2 draw pass is only 143 ms at 300 lines. **Memoization, not skipping passes, is the lever:** make expensive work a pure function of data.

**What the 2nd pass currently fixes:** only the siblings that read totals, bank and payment-means (list in §1). Items, line-items, the table, the totals block and the frame need just one pass.

##### Further measured facts for the format

- **Data in ctx:** `invoice(data: DATA)` with 300 rows put into weave inputs (ip-data, p5/\*):
  - per-item motifs: 5.69 → **7.86 s** unsealed, 5.82 s sealed in `metadata()`;
  - item-rows: 2.97 → 3.26 / 3.06;
  - 50 lines: 1.26 → 1.40 / 1.16.
- **`static` motif:** 120 styled blocks in the body: 0.784 → 0.623 s with `loom.construct-loom(<invoice-pro:0.6.0>).prebuild-motif.static[..]` (motifs.typ:121); identical PDF. Not re-exported by loom-wrapper.typ.
- **CLI:** `json(bytes(sys.inputs.data))` and `json(sys.inputs.file)` work on 0.14.2 and 0.15.1. JSON numbers arrive as int/float, so money should be strings. 0.15.1: `typst query` is deprecated (hint: `typst eval 'query(<l>).first().value' --in f.typ`); 0.14.2 has no `eval`.

##### Remaining hot spots after P2 (b-300-plain, traced)

- Typst layout ≈ 1.9-2.2 s (3 iterations; outside loom).
- line-items measure ≈ 350 ms: `format-item` via `loom.mutator.batch` per item (line-items.typ:166-247), pass 1 only.
- item-rows `compute-rows` ≈ 240 ms in pass 1, ~18 ms in pass 2.
- modifier-applicator ≈ 70 ms.
- EPC-QR ≈ 40 ms; imports ≈ 130 ms.

#### 4. loom APIs to feed precomputed data

- `weave(inputs:)`: initial ctx. Already used for every invoice() param (invoice.typ:563-617). Note the existing comment at invoice.typ:598-600: every ctx value costs time on long invoices.
- `injector(ctx, payload) => dict`: free to ignore the payload and return precomputed data. Called once per pass; with max-passes: 1, once with `()`.
- `max-passes: 1`: draw-only weave (P1/P3). `handle-nonconvergence`: diagnostics only.
- `loom.core.intertwine(ctx, content, key:, draw:)`: run loom on a tiny subtree in plain code. Used by item.typ:25-29 (`normalize-modifier`), loom-wrapper.typ:24-34 (`eval-content`) and P4.
- Raw `motif` + `loom.frame.new(kind, key, path, signal)` returning **an array of frames**: bulk signal emission (P2).
- `apply` (invoice-pro's own compute-motif, loom-wrapper.typ:18-22): scope injection for a subtree.
- `static` (prebuilt): exclude content from traversal.
- `dynamic(ctx => ..)` (components/dynamic.typ:310): a draw-only content motif for data-dependent output (e.g. a coat of arms (Wappen) by postal code).
- loom 0.1.1 has **no** "prebuilt signal" or cache API. The only cross-pass cache is Typst's closure memoization.
- Upstream doc guidance agrees (typst.app/universe/package/loom): "do not use it for the flesh … thousands of data points".

#### Prototype diff (ip-var vs src)

- **invoice.typ:** new param `global: auto`. If given: `weave(max-passes: 1, injector: (ctx, payload) => ctx + (global: global), root(body))`; else the original call.
- **root.typ draw:** captures `injected-global = ctx.at("global")`; with `--input ip-dump-global=1` emits `[#metadata(repr(injected-global))<ip-global>]`.
- **New components/item-rows.typ:** `settings-of(ctx)`, `compute-rows(rows, s)`, `item-rows(rows)`.

Bench files:

- `bench/` (gen_bench.py output, imports @preview/invoice-pro:0.6.0);
- `p1/base-*`, `p1/v1p-*` (P1), `p1/g-*` (dumped globals);
- `p2/v2p-*` (P2), `p2/v1p-*` (P3);
- `p4/` (precompute, static test);
- `p5/` (ctx data test).
