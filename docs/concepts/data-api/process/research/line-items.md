# Research: Line items and their calculations

Phase-1 reader `line-items` of the data-API exploration (2026-11-02). Facts marked [v] were verified (read or run), [i] are inferences. `<repo>` is the repository root, `<session>` the scratch directory of the exploration (not part of the repository).

## Summary

All line-item calculations are pure functions that read a small set of context keys: calculate-item-data(ctx, name), calculate-modifier(ctx, frames), calculate-taxes(ctx, frames), calculate-bundle(ctx, frames, name) and resolve-tree(frames). The loom motifs mostly copy component arguments into ctx through loom.mutator.batch and then call these functions. That copying is where the time goes. Each mutator op is a closure call that gets the whole ctx (34 keys, about 330 leaves plus the locale's closures), and any closure call carrying the full ctx costs about 22 µs (measured). An item's scope runs dozens of these ops, which comes to about 1.9 ms. Its measure adds about 0.5 ms, and both run again in the second weave pass, so an item costs about 2.4 ms per pass and nothing is shared between passes. I built a working prototype (exp/line-items/fast/rows.typ): ONE motif inside line-items turns a JSON tree (items, groups, bundles, item/bundle/global modifiers, prepayments) into the same kind of frames that item/group/bundle/modifier/prepayment emit. It reuses the unchanged calc functions, applicators, tree and line-items measure. Against hand-written motifs it gives the same item-data, totals, taxes and ZUGFeRD model, and pixel-identical PNG output. The only differences are str instead of content for names, and decimal scale such as "100.00" vs "100", which is numerically equal and gives the same XML. Data rows can be mixed with static skeleton items and placed inside a group; numbering continues (1, 2, 3, 4.1…). Speed: the per-item work drops about 10× (200 rows: 93 ms over both passes, and pass 2 is almost all memo hits because per-row arguments are pass-independent). Whole-document eval drops 2.7–3.6× (N=500: 5.47 s to 1.52 s). End-to-end time goes 12.6 s to 6.8 s at N=500 and 30.3 s to 17.2 s at N=1000. After that, the theme's items-table layout dominates: its keep-together `fits()` measures every entry in each of 3 layout iterations. I also found a silent correctness bug: calculate-modifier collects items with depth 10, so an item nested in 10 or more groups is still printed but left out of the totals.

## Key facts

- [v] weave(max-passes: 2) = exactly 1 measure pass + 1 draw pass; every motif's scope and measure therefore runs twice per compile, draw once (src/invoice.typ:620-627; <loom>/src/core/runtime.typ (measure-limit = max-passes - 1, then final draw intertwine); trace: item.typ:200 scope called 400× for 200 items)
- [v] item = data-motif "item" (managed frame, body none). Scope (loom.mutator.batch) copies ~20 values into ctx; measure = calculate-item-data(ctx, name) + (style: row-style-of(ctx)); draws nothing (src/components/item.typ:198-299)
- [v] bundle = compute-motif name "bundle" with its body wrapped in modifier-applicator; measure = calculate-bundle, which returns an array of virtual frames of kind "item", one per VAT bracket (name suffixed "(19% S)" if several brackets). Nested bundles and the consumed items/modifiers are stripped (src/components/bundle.typ:97-182; src/logic/calc-bundle.typ:7-85,125-221)
- [v] group = compute-motif name "group"; signal (kind:"group", name, description, show-subtotal, style, children). Cascades tax (resolved), input-gross, date and an UNRESOLVED unit to descendants. The subtotal is computed later in resolve-tree (src/components/group.typ:64-129; src/logic/tree.typ:250-292)
- [v] modifier/discount/surcharge = data-motif "modifier"; signal (name, label[resolved from locale if auto], description, type relative|absolute, amount [decimal ratio or money-rounded decimal], is-gross, tax[none = split]). discount/surcharge require amount ≥ 0 and flip the sign (src/components/modifier.typ:64-150,153-262)
- [v] prepayment = data-motif "prepayment" (direct parent must be line-items); signal (name, label, date[formatted via locale if datetime], reference, description, method, type, raw-amount, amount) (src/components/prepayment.typ:74-150)
- [v] line-items = managed-motif; body wrapped as tax-applicator(modifier-applicator(body)); measure returns (public, view); draw = call-part("line-items", view) + call-part("notes", ...) + body (src/components/line-items.typ:80-136,137-710,711-725)
- [v] Rounding is per line: price → money-fine (4 dp default), line total → money (currency decimals, 2 dp), each relative modifier → money; per VAT group, exclusive mode: tax = money(net×rate); inclusive mode: net = money(gross/(1+rate)), tax = gross − net. Decimal calc.round rounds half away from zero (0.125 → 0.13, −0.125 → −0.13) (src/logic/calc-item.typ:64-200; src/logic/tax-applicator.typ:6-143 (lines 112,122); src/locale/region/base.typ:46,51; exp misc/parse.typ)
- [v] Absolute global modifiers are split over VAT groups in proportion to group totals (only groups with the sign of the total); the rounding remainder goes to the largest group; gross/net conversion uses the rate mix; a pinned `tax` puts the modifier into one group (and adds that group if needed) (src/logic/modifier-applicator.typ:25-55,57-160,187-237)
- [v] Quantities are rounded to 4 decimals before any calculation; base-quantity must be > 0 after rounding (src/logic/calc-item.typ:6-46)
- [v] Per-item cost of the motif path: item scope ≈1.9 ms and item measure ≈0.5 ms per pass (N=200, 400 calls: 769.5 ms and 200.1 ms). The cost comes from mutator ops that each take the whole ctx (34 keys, 330 leaves; locale = 215 leaves) (trace analysis (exp/line-items/analyze2.py on bench-items.typ n=200); exp memo/ctxsize.typ)
- [v] A closure call with the full ctx as argument costs ≈22 µs (hashing for memoization); with only ctx.locale ≈15.6 µs; with a small dict ≈3.4 µs (exp memo/hashcost.typ, 1000 calls per loop, typst 0.14.2 --timings)
- [v] Typst memoizes closure calls per call-site and argument value: identical args from the same call site are cache hits, including across the two loom passes. The fast path's per-row function executed 200× for 400 calls (all of pass 2 hit). The line-items format-item likewise ran only 200× for 2 passes (exp memo/m2.typ, memo/probe.typ, bench trace counts (rows.typ:141 called 400×, body lines 142+ executed 200×))
- [v] The fast-path prototype gives the same item-data, totals, taxes, splits, bundle virtual items, group positions and prepayments as the motif path. The rendered PNG pages are byte-identical. The ZUGFeRD model differs only in decimal scale (exp eq/motif.typ vs eq/data.typ (+data.json); eq/\*-z.typ build-model diff; `cmp` on eq/motif-N.png vs eq/data-N.png)
- [v] A custom field (`custom: {...}`) added to the item signal passes through format-item into view.entries/items without breaking rendering or the embedded EN16931 XML (exp eq/data-xml.typ compiled with --pdf-standard a-3b, XML extracted (LineTotalAmount 180.00, 525.00, …))
- [v] Data rows can be mixed with static items in a skeleton and placed inside group(); positions continue (1, 2, 3, 4.1, 4.2) and cascades (group tax 7%, line-items tax 19%) apply (exp eq/mixed.typ: net 117.00, gross 135.99 (checked by hand))
- [v] BUG: calculate-modifier collects items with collect-signals(depth: 10). With 10 or more nested groups the leaf item is still listed (resolve-tree has no depth limit) but is left out of the totals: net 1 instead of 11 (src/logic/modifier-applicator.typ:188; exp eq/depth.typ (d=8,9 → 11; d=10,12 → 1))
- [v] A cascaded line-items(tax: 19%) stays a raw ratio in ctx.tax; each item resolves it via update("tax", m-tax.resolve). Any data path must replicate this (the prototype crashed until it did) (src/components/line-items.typ:100; src/components/item.typ:251-256; exp eq/mixed.typ error 'cannot access fields on type ratio')
- [v] The theme items-table (render-table) reads, per entry: kind, pos, name, has-date, date, description, has-description, has-discounts/has-surcharge, discounts/surcharge[(name,label,is-percent,display,absolute)], quantity, unit, price, tax.rate/category/marker, unmodified-total, total, style.fill. For groups it reads name, description, has-description, subtotal and style. It also reads layout-information.show-\*, tax-mode and tail. The compact look reads the same fields (src/themes/components/line-items/table.typ:6-117,411-834,836-1112,1120-1245; columns.typ:1-53; src/theming/looks/compact.typ:225-410)
- [v] After the fast path, layout dominates: at N=200 layout ≈1.9 s over 3 iterations, with the keep-together `fits()` measure ≈1.5 ms per entry per iteration. keep-together is always on; it is not exposed in theme options (trace bench/data.typ n=200 (table.typ:1120/1121/1126); grep keep-together finds it only in table.typ)
- [v] JSON null → none, absent → (use auto); TOML gives native datetimes, JSON/YAML need ISO string parsing; json(bytes(sys.inputs.data)) works on 0.14.2 and 0.15.1; eval("19%") == 19% and float("7.7")\*1% == 7.7% are both true (exp misc/parse.typ queried with both binaries)
- [v] typst 0.15 deprecates `typst query` in favour of `typst eval 'expr' --in file`; a pure calc (calculate-item-data) runs via `typst eval` in ~37 ms without layout (typst eval --help; exp misc/calc-only.typ)

## Implications

- Hydration needs no per-item motifs. One new motif (e.g. `rows(data)` / `items(data)`) placed in the skeleton inside line-items, group or bundle can emit the same frames, and every downstream stage (applicators, resolve-tree, line-items view, theme parts, ZUGFeRD) stays as it is. This only extends the public API (a new export).
- To avoid divergence, item/bundle/modifier/prepayment should each get a shared pure function ('inputs → signal') that both the Typst component and the data path call. For item that means the scope part of item.typ:200-293 (resolution + defaults), for modifier/prepayment the measure parts. This is an internal refactor with no API change.
- Per-row functions must take SMALL, pass-independent arguments (row + env subset: normalize closures, tax-mode, resolved default tax, unit labels). Then pass 2 is memo hits and cost per row stays ≈3 µs overhead instead of ≈22 µs per closure call. Do not pass ctx or the full locale per row; pre-resolve unit labels and tax per distinct value.
- The data format should be a tree with a `kind` discriminator (item | group | bundle | discount | surcharge | modifier | prepayment), or separate `items`/`modifiers`/`prepayments` arrays, with kebab-case keys mirroring the Typst parameter names. JSON-absent = Typst auto (inherit/default), JSON null = Typst none. Groups, bundles and items take `items`/`modifiers` children.
- Money and quantities should be strings ("19.99") in the format: JSON floats are tolerated (to-decimal rounds to 15 digits) but lose precision for large values. Percentages as "19%" strings, parsed to exact ratio literals (the regex-gated eval, or float\*1%), because locale infer-tax compares `rate == 19%`.
- Tax in data: "19%" (region infer-tax; DE panics on 0%), or an explicit object {rate, category, grounds, code, label}, or the presets "exempt"/"reverse-charge". A 0% rate must use an explicit category.
- Dates: "YYYY-MM-DD" or [start, end] strings, parsed to datetime (TOML input gives datetimes natively). Units: a name from the public unit module ("hour", "h", "pcs", …) resolved via dictionary(unit-module), or {display, code}, or free text (ZUGFeRD then guesses the code by alias).
- Text fields (name, description, note, group/bundle name, modifier name/label/description, prepayment fields, tax grounds) are str|content in Typst. Plain strings work everywhere (the view wraps them in [#x]). Rich markup would need opt-in eval(mode: "markup"), which can read files inside --root.
- Custom fields can ride along as `custom: {...}` on the item signal and appear in view.entries and items for theme parts and hooks without breaking ZUGFeRD.
- Speed ceiling: the fast path removes ~2.4 ms per item per pass of eval (eval 3.6× faster at N=500), but the theme table layout (~5 s at N=500) then dominates. The FAST requirement will also need theme-side work: cheaper keep-together, or an option to disable it, and fewer layout iterations. format-item's mutator.batch (~1 ms per item) can be replaced by a plain dict merge (~10× faster in a microbenchmark).
- A schema for phase 2 can be derived 1:1 from the parameter tables in raw_notes. `typst eval` (0.15) can run the pure calculation for validation and totals without layout, which is a useful CLI and binding primitive.
- Removing the first weave pass is NOT straightforward: payment-terms, bank-details (EPC QR), payment-means, frame and info.total.\* read ctx.global totals produced by line-items in pass 1. It would only be possible if line-items data and its env were known at invoice() level before weave.

## Risks

- Semantic drift between item() and the data path. Cascades are subtle: a raw-ratio tax from line-items, description/date/unit/item-id inherited via ctx, tax-exempt-small-biz override, input-gross default from tax-mode, the bundle-only note/origin panic, discount/surcharge sign and label resolution, and dictionary item modifiers bypassing sign flips. Mitigation: shared pure functions plus equivalence tests (motif vs data).
- Validation is skipped: types.require and the guards in the components do not run for data rows. The data path needs its own validation with error messages that name the data path (items[3].price), ideally generated from the same schema.
- Silent wrong totals for 10 or more nested groups (collect depth 10 in modifier-applicator.typ:188). The data format must cap nesting depth, or the collector must be fixed. A wrong total with a correct-looking table also breaks the XML sums.
- eval-based parsing: gate percent parsing with a regex. Generic markup eval of data strings lets data read files under --root (read/json/image). It must stay opt-in.
- Float inputs from JSON give decimal-scale and precision differences: numerically equal and the XML prints the same, but repr and possibly custom parts differ ("100.00" vs "100").
- Region infer-tax: DE accepts only 19%/7% as ratios and panics otherwise, so data with "16%" or "0%" fails compilation. The data format must offer explicit tax objects.
- Passing the full locale or ctx per row costs ~16–22 µs per call and also breaks cross-pass memo reuse if anything pass-dependent leaks into the args.
- Layout (theme) cost is now the bottleneck for large invoices: ~5 s of the 6.8 s at N=500. Users may judge the feature 'not fast' even with the data fast path.
- Bundles in the prototype still pass the full ctx into calculate-bundle (it needs sys.path for loom.path.current/get and the theme for row-style). That is fine for few bundles but not memo-friendly. The prototype also does not inherit a group date into bundle-date (item.typ/bundle.typ do).
- Minor existing quirks: line-items `show-information` has no types.require; group puts an unused `group-description` into ctx; bundle `put("bundle-description", ctx.at("description", default: description))` reads the PARENT's description first, so nested bundles may take the outer description (inferred, not observable in output because inner lines are consumed).

## Open questions

- Hydration entry point: a new component placed in the skeleton (`#rows(data.items)` inside line-items/group/bundle), a new named `data:` parameter on line-items (a backward-compatible extension, since body is positional and required), or invoice-level data? A slot component allows mixing static and data rows (verified).
- One mixed `items` array with `kind` discriminators (mirrors Typst body order), or separate `items`/`modifiers`/`prepayments` arrays (cleaner schema)? Should bundles allow modifiers inside `items` or only in a separate `modifiers` array?
- Should data rows support every item() parameter (item-id dict, origin, note, base-quantity, input-gross, date ranges), or a documented subset first?
- Plain text only for descriptions, or an opt-in markup field (e.g. {"markup": "_bold_"})? What sandboxing is acceptable?
- Should the data path go through a single shared pure-function layer refactored out of item.typ/bundle.typ/modifier.typ/prepayment.typ (recommended), or be a parallel implementation?
- Should the depth-10 collector bug be fixed in this feature (it is a loom.query default), or capped in the schema?
- Is theme-side speed (keep-together measure, 3 layout iterations) in scope for 'fast', or does phase 1 only target eval?
- Field-dependent changes in line items (e.g. row style or tax by category): left to user-side preprocessing in Typst (data.items.map(...)), or a declarative rule/hook in the format?

## Measurements

- Baseline motif path (bench-items.typ, de-de, 19% ratio tax, description, typst 0.15.1, wall clock): n=1 0.37 s, n=50 1.58 s, n=200 6.30 s (first run; 3.47 s compile under --timings), n=500 13.3 s. Command: typst compile --root . --input n=N bench-items.typ out.pdf
- Trace n=200 motif path: eval 1894 ms; layout iter1 808 + iter2 700 + iter3 71 ms. Item scope (item.typ:200) 769.5 ms/400 calls; item measure (item.typ:294) 200.1 ms/400; line-items measure 236 ms/2 calls (format-item 203.7 ms/200 calls, memoized in pass 2); table fits() 545 ms/400 calls. Command: typst compile --timings trace.json …; python3 analyze2.py trace.json
- Motif loop vs fast path, same JSON data (bench/motif.typ vs bench/data.typ, best of 2): n=1 0.32 vs 0.31 s; n=50 1.24 vs 0.86 s; n=200 4.43 vs 2.85 s; n=500 12.60 vs 6.80 s; n=1000 30.3 vs 17.2 s. Command: typst compile --root . --input n=N bench/{motif,data}.typ
- Phase split at n=500 (--timings): motif eval 5468 ms, layout 2419+2852+296 ms; fast path eval 1522 ms, layout 2241+2530+231 ms
- Fast path cost at n=200: rows measure 93 ms over both passes (pass 1 ≈80 ms, pass 2 ≈13 ms, all memo hits); calculate-item-data 29.8 ms per 200 calls (0.15 ms/item); applicators ~50 ms; line-items measure 244 ms (format-item 213 ms, pass 1 only)
- Closure-call hashing cost (memo/hashcost.typ, 1000 calls/loop): full ctx 21.9 µs/call, ctx.locale 15.6 µs/call, small dict 3.4 µs/call
- ctx size seen by line-items children: 34 keys, 330 leaves, repr 60 kB (theme sealed in metadata = 1 leaf, repr 44.5 kB; locale 215 leaves) — memo/ctxsize.typ
- format-item microbenchmark n=500: mutator.batch 0.40 s vs plain dict merge 0.12 s (incl. ~0.1 s startup) — misc/fmt.typ
- Equivalence: eq/motif.typ vs eq/data.typ → repr(item-data) differs only in str-vs-content names and decimal scale; 3 PNG pages byte-identical (typst compile --ppi 60; cmp)
- Depth bug: eq/depth.typ, d=8/9 → net 11, d=10/12 → net 1 (2 items listed in each case)
- typst eval --root . --in misc/calc-only.typ 'query(<calc>).first().value' → {"total":"59.97","price":"19.99"} in 0.037 s

## Notes

### Line-item tree: components, calculations, fast path

All experiment files are under `<session>/exp/line-items/`:

- `ip/` is a copy of the repo's `src`.
- `fast/rows.typ` is the prototype.
- `eq/` holds the equivalence tests, `bench/` the benchmarks, `memo/` the memoization and hashing probes.

The repo itself is untouched (`git status` is clean).

---

#### 1. Component parameters (verified from source)

##### `line-items(..)` — src/components/line-items.typ:18

| param            | type                                                                                                          | default   | resolution                                                                           |
| ---------------- | ------------------------------------------------------------------------------------------------------------- | --------- | ------------------------------------------------------------------------------------ |
| input-gross      | bool \| auto                                                                                                  | auto      | becomes `tax-mode == "inclusive"` (put into ctx, :90-96)                             |
| tax              | ratio \| tax dict \| auto                                                                                     | auto      | `derive` (raw, NOT resolved; items resolve it); default `tax.implicit-zero()` (:100) |
| tax-mode         | "exclusive" \| "inclusive" \| auto                                                                            | auto      | ctx.tax-mode (invoice) or "exclusive"                                                |
| show-column      | auto \| dict{pos, description, modifier, date, quantity, unit, unit-price, total-price, tax-rate: auto\|bool} | auto      | merged with ctx.show-column                                                          |
| show-total       | auto \| bool                                                                                                  | auto→true |                                                                                      |
| show-information | auto \| bool                                                                                                  | auto→true | no `types.require`                                                                   |
| body             | content (positional)                                                                                          | required  | wrapped as `tax-applicator(modifier-applicator(body))` (:721-724)                    |

##### `item(name, ..)` — src/components/item.typ:80

| param         | type                                                                                                           | default / cascade                                                                                                                                                  |
| ------------- | -------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| name          | str \| content (positional)                                                                                    | required                                                                                                                                                           |
| description   | str \| content \| auto \| none                                                                                 | auto: inherits ctx.description, else none                                                                                                                          |
| quantity      | int\|float\|decimal\|str \| auto                                                                               | auto: ctx.quantity (`apply`) or 1; rounded to 4 dp                                                                                                                 |
| base-quantity | same                                                                                                           | auto: 1; must be > 0 after rounding                                                                                                                                |
| unit          | str \| content \| (display, code) dict \| unit fn \| dict \| auto \| none                                      | auto: ctx.unit (group/apply, unresolved) or `unit.pc`; resolved with plural by quantity, plus `unit-singular`                                                      |
| date          | datetime \| (datetime, datetime) \| auto \| none                                                               | auto: ctx.date (group/bundle cascade)                                                                                                                              |
| price         | decimal-like \| auto                                                                                           | price XOR total                                                                                                                                                    |
| total         | decimal-like \| auto                                                                                           |                                                                                                                                                                    |
| input-gross   | bool \| auto                                                                                                   | ctx.input-gross or tax-mode=="inclusive"                                                                                                                           |
| tax           | ratio \| tax dict \| auto                                                                                      | auto: ctx.tax (resolved via `update`) else implicit-zero; a ratio goes through locale `infer-tax`; `tax-exempt-small-biz` overrides with the small-business scheme |
| item-id       | str \| dict(seller, buyer, standard) \| auto \| none                                                           | a str becomes the seller id (`coercion.to-item-id`)                                                                                                                |
| reference     | str \| auto \| none                                                                                            | str only                                                                                                                                                           |
| note          | str \| content \| auto \| none                                                                                 | BT-127; panics inside a bundle                                                                                                                                     |
| origin        | country fn \| dict \| ISO2 str \| content \| auto \| none                                                      | BT-159; panics inside a bundle; becomes a code via `origin-code`                                                                                                   |
| modifier      | content (discount/surcharge) \| array of (content \| dict(name, description, amount[, label])) \| auto \| none | auto: ctx.modifier; content is normalized by a nested `loom.core.intertwine` per item (item.typ:15-47)                                                             |

##### `bundle(name, .., body)` — src/components/bundle.typ:17

| param              | type                                                                                                                | default                                                                                                     |
| ------------------ | ------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------- |
| name, description  | text-like; description auto: item names per VAT bracket joined with the locale conjunction (calc-bundle.typ:87-115) |                                                                                                             |
| quantity           | decimal-like \| auto                                                                                                | 1 (NOT inherited from an outer bundle)                                                                      |
| base-quantity      | decimal-like \| auto                                                                                                | 1                                                                                                           |
| unit               | like item                                                                                                           | auto: cascaded unit or `unit.pcs`; resolved into `bundle-unit`; ctx.unit is still passed on to the children |
| date               | date-like \| auto \| none                                                                                           | auto: cascaded date, else min/max of the item dates                                                         |
| input-gross        | bool \| auto                                                                                                        |                                                                                                             |
| tax                | tax-like \| auto                                                                                                    | default for the children                                                                                    |
| item-id, reference | like item                                                                                                           |                                                                                                             |
| body               | content                                                                                                             | items, nested bundles, discount/surcharge/modifier                                                          |

A bundle has no `modifier` parameter: bundle modifiers are children in the body.

##### `group(name, .., body)` — src/components/group.typ:14

| param         | type                      | default                                                    |
| ------------- | ------------------------- | ---------------------------------------------------------- |
| name          | text-like                 |                                                            |
| description   | text-like \| auto \| none | none                                                       |
| show-subtotal | bool \| auto              | auto: true                                                 |
| tax           | tax-like \| auto          | cascaded, resolved                                         |
| input-gross   | bool \| auto              | cascaded                                                   |
| date          | date-like \| auto \| none | cascaded                                                   |
| unit          | like item                 | cascaded unresolved                                        |
| body          | content                   | items, bundles, groups. Modifiers are NOT allowed (guard). |

##### `modifier(name, ..)` — modifier.typ:10; `discount` :153; `surcharge` :208

| param       | type                                        | default                                                                          |
| ----------- | ------------------------------------------- | -------------------------------------------------------------------------------- |
| name        | text-like                                   |                                                                                  |
| label       | none \| auto \| text-like                   | auto: locale `strings.line-items.discount`/`surcharge`                           |
| description | text-like \| auto \| none                   |                                                                                  |
| amount      | ratio (relative) \| decimal-like (absolute) | modifier: auto→0; discount/surcharge: 0, must be ≥ 0 (sign flipped for discount) |
| input-gross | bool \| auto                                | tax-mode=="inclusive"                                                            |
| is-discount | bool \| auto                                | modifier only, internal                                                          |
| tax         | ratio \| dict \| auto                       | auto = split over the VAT groups; pinned = one group                             |

##### `prepayment(amount, ..)` — prepayment.typ:9

`amount` is decimal-like or a ratio (abs is taken). `name`, `label` (auto: locale `summary.prepayment`), `date` (datetime \| text), `reference`, `description` and `method` are text-like \| auto \| none. The direct parent must be `line-items`.

---

#### 2. Loom implementation

| component           | motif type                                                   | scope sets                                                                                                                                                                                                   | measure emits (signal)                                                                                     | draws                                                                            |
| ------------------- | ------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ---------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------- |
| line-items          | managed-motif "line-items"                                   | input-gross, tax, tax-mode, tax-exempt-small-biz, show-column, show-total, show-information, locale.format guards                                                                                            | `(public, view)` — see below                                                                               | `call-part("line-items", view)` + `call-part("notes", view + (required))` + body |
| tax-applicator      | raw compute-motif                                            | locale.normalize guards                                                                                                                                                                                      | `[frame("tax-applicator", calculate-taxes)] + children`                                                    | —                                                                                |
| modifier-applicator | raw compute-motif                                            | locale.normalize guards                                                                                                                                                                                      | `[frame("modifier-applicator", calculate-modifier)] + children − top-level "modifier" frames`              | —                                                                                |
| item                | data-motif "item"                                            | description, quantity, base-quantity, unit, unit-singular, date, item-price, item-total, tax-mode, input-gross, tax, item-id, reference, note?, origin?, modifier                                            | `calculate-item-data(ctx, name) + (style: row-style-of(ctx))`                                              | nothing                                                                          |
| bundle              | compute-motif "bundle" (managed) + inner modifier-applicator | description, bundle-description, bundle-quantity, bundle-base-quantity, bundle-unit(-singular), date, bundle-date, input-gross, tax-mode, tax, item-id, reference; removes quantity, base-quantity, modifier | array: non-consumed layout children + one virtual `item` frame per VAT bracket (`create-virtual-tax-item`) | —                                                                                |
| group               | compute-motif "group" (managed)                              | group-description (unused), input-gross, date, tax, unit                                                                                                                                                     | (kind, name, description, show-subtotal, style, children)                                                  | —                                                                                |
| modifier            | data-motif "modifier"                                        | modifier-tax, modifier-amount, description, input-gross, label                                                                                                                                               | (name, label, description, type, amount, is-gross, tax)                                                    | —                                                                                |
| prepayment          | data-motif "prepayment"                                      | prepayment-amount, name, label, date, reference, description, method                                                                                                                                         | (name, label, date, reference, description, method, type, raw-amount, amount)                              | —                                                                                |
| apply               | raw compute-motif (loom-wrapper.typ:18)                      | `ctx + args.named()`                                                                                                                                                                                         | children                                                                                                   | —                                                                                |

Guards: item and bundle need a direct parent line-items, bundle or group; group needs line-items or group; modifier needs line-items or bundle; prepayment needs line-items.

##### Signals in detail

**Item signal** (calc-item.typ:177-199):

- name, description, date
- quantity, base-quantity, unit, unit-singular
- price (money-fine), total (with modifiers), unmodified-total
- tax: rate, category, grounds, code?, implicit?
- discounts, surcharge — each `[(name, label, description, type, display, absolute)]`
- item-id (seller, buyer, standard) \| none, reference, note, origin (ISO code)
- style (added by the item motif)
- pos (added by resolve-tree)

**modifier-applicator signal:**

- tax-rates
- modifier: (discounts, surcharges) — each `(name, label, description, type, display, absolute, split: {key: (tax, absolute)})`
- tax-split: (discounts, surcharges), each `{key: [...]}`
- items
- tax-groups: (total, keys, groups: {"<rate>-<cat>": (total, tax, grounds-list, missing-grounds, items)})

**tax-applicator signal:**

- unmodified-net-total, unmodified-gross-total, net-total, gross-total
- taxes: {key: (rate, category, grounds, grounds-list, missing-grounds, codes, implicit, absolute, basis)}

**line-items public** (:674-707):

- total: (net, gross, due, prepaid)
- formated-total
- item-data: items (tree order, with pos), taxes, net-total, gross-total, unmodified-net-total, due-total, prepaid-total, prepayments, tax-mode, discounts, surcharges, dates-printed

Root collects this for ZUGFeRD and `ctx.global` (root.typ:190-303).

**line-items view** (:654-672):

- items, entries — kind item / group-header / group-footer, formatted
- discounts, surcharges, prepayments
- taxes (formatted, with markers)
- exemption-notes, total, unmodified-total
- layout-information: show-pos, show-descriptions, show-modifier, show-dates, show-quantity, show-units, show-unit-price, show-total-price, show-tax-rates, show-total, show-global-information, has-dates, multiple-dates, multiple-quantities, multiple-units, multiple-tax-rates, has-global-modifier, has-prepayments
- tax-mode, tax-exempt-small-biz
- totals: (rows, payable)
- The composite adds `tail`; `notes` gets `required`.

##### Formatted entry (format-item, :166-247)

All raw keys, plus:

- name and description as content; has-description
- date → format.date; has-date
- quantity and base-quantity → format.number
- unit and unit-singular → content (display)
- price → currency-fine; total and unmodified-total → currency
- tax → (rate: percent str, category, marker)
- has-discounts / discounts → (name, label, description, display, absolute, is-percent, has-description); the same for surcharge
- has-item-id, has-reference
- entry adds kind, pos, level, style

Group header: (kind, pos, level, name, description, has-description, style). Group footer: (kind, pos, level, name, subtotal: formatted currency, raw-subtotal, style).

##### What theme parts consume (needed for a fast path that builds the view directly)

**table.typ render-table** reads:

- `data.layout-information`: show-pos, show-quantity, show-unit-price, show-tax-rates, show-total-price, show-units, show-dates, show-modifier, show-descriptions
- `data.tax-mode`, `data.entries` (fallback `data.items`)
- per item: name, has-date, date, description, has-description, has-discounts, has-surcharge, discounts/surcharge (label, name, is-percent, display, absolute), quantity, unit (content or dict display/name), price, tax.rate, tax.category, tax.marker, unmodified-total, total, style.fill
- per group: pos, name, has-description, description, subtotal, style.fill
- `tail`

**global-info (notes part):** layout show/multiple flags, items.first() tax.rate/unit-singular/quantity/date, tax-exempt-small-biz, exemption-notes.

**totals part:** view.totals.rows (kind, label, value.text, emphasis, rate, name), tax-mode.

**compact look (looks/compact.typ:225-410):** the same entry fields.

So the fast path should keep producing the same frames and leave the line-items measure as the single producer of the view (recommended), rather than building the view itself.

---

#### 3. Where totals, VAT grouping and rounding happen

1. **calculate-item-data** (calc-item.typ:64):
   - qty = round4(q); mult = q/bq
   - tax-modifier = 1/(1+r) for exclusive mode with gross input, (1+r) for inclusive mode with net input
   - price = money-fine(price·tm) or total/mult
   - base-total = money(price·mult)
   - relative modifier = money(rate·base-total), absolute = money(amount)
   - total = base + Σ modifiers
   - panics if an item modifier pins a different tax
2. **calculate-bundle** (calc-bundle.typ:154): modifier-applicator over the children gives group totals per VAT bracket. Per bracket, a virtual item with price = money-fine(bracket total), total = money(price·q/bq); relative bundle modifiers are rescaled to the line.
3. **calculate-modifier** (modifier-applicator.typ:187): `group-by-tax` sums item totals by key `"<ratio>-<category>"`. Global modifiers:
   - relative: money(group.total·r) per group
   - absolute: gross↔net conversion with the rate mix, proportional split, remainder to the largest group
   - pinned tax: one group
4. **calculate-taxes** (tax-applicator.typ:6):
   - exclusive: tax = money((group + mods)·rate)
   - inclusive: net = money(gross/(1+r)), tax = gross − net
   - default exemption grounds for AE/K/G/O
5. **line-items measure:** relative prepayments = money(gross·p); due = gross − prepaid; totals row model.
6. **net-amounts.typ:** only for e-invoices with gross prices (largest-remainder allocation of net amounts).

All money is Typst `decimal`. money/money-fine come from the locale (`calc.round` to currency decimals / decimals-fine, i.e. 2/4; currency-dependent via with-currency, data/currency.typ:199).

**Fast-path feasibility: YES, verified.** All functions are pure in (ctx-subset, frames). `calculate-item-data` reads only:

- locale.normalize.{money, money-fine}
- quantity, base-quantity, unit, unit-singular
- tax-mode, input-gross, tax
- item-price, item-total
- modifier, description, date
- item-id, reference, note, origin

---

#### 4. Value types

- **Content-typed (str \| content):** item name/description/note; unit display; bundle and group name/description; modifier name/label/description; prepayment name/label/date/reference/description/method; tax grounds/label. The view always wraps them in `[#x]`, so plain strings work.
- **str-only:** item.reference, item-id strings, tax category, tax code.
- **Units:** the public unit module exposes 76 names (hour/hours/h/hr/hrs, day, month, year, piece/pc/pcs/stk, set, pair, lump-sum, kg, g, t, m, m2, mm, cm, km, l, m3, …). Each is a function `locale => (code, name, display)` with localized singular/plural strings (lang/de.typ:126-145). It can also be a dict (display, code) or free text; ZUGFeRD maps text by alias (zugferd/model.typ:747).
- **Tax:** the `tax` module constructors: vat(r) S, zero Z, exempt E (grounds, code), reverse-charge AE, intra-community K, export G, outside-scope O, special.\*, new(rate, category, label, grounds, code). A ratio goes through the region's `infer-tax` (DE: only 19%/7%; panics on 0% and other rates, region/de.typ:5-27). `none` gives implicit-zero; `"exempt"`/`"reverse-charge"` strings are accepted by `to-tax`. The group key is `str(to-ratio(rate)) + "-" + category`.
- **Dates:** datetime or (datetime, datetime). A day is required (`require-day`). format.date from the locale.

---

#### 5. Proposed JSON shape (prototype-tested subset)

```json
{
  "tax": "19%", "tax-mode": "exclusive",
  "items": [
    {"name": "Consulting", "description": "…", "quantity": "2", "unit": "hour",
     "price": "100.00", "tax": "19%", "date": "2026-01-03",
     "item-id": {"seller": "A-1", "standard": "4012345678901"}, "reference": "PO-7",
     "note": "…", "origin": "DE",
     "modifiers": [{"kind": "discount", "name": "Loyalty", "amount": "10%"}],
     "custom": {"cost-center": "CC-42"}},
    {"kind": "group", "name": "Phase 1", "description": "Konzeption", "tax": "7%",
     "show-subtotal": true, "date": ["2026-01-01", "2026-01-31"], "unit": "hour",
     "items": [ {"name": "Workshop", "price": 200},
                {"kind": "group", "name": "Sub", "items": [ … ]} ]},
    {"kind": "bundle", "name": "Development", "quantity": "1", "unit": "set",
     "items": [ {"name": "Backend", "price": "300.00", "tax": "19%"},
                {"name": "Docs", "price": "150.00", "tax": "7%"},
                {"kind": "discount", "name": "Partner", "amount": "50.00"} ]},
    {"name": "Exempt service", "total": "100.00",
     "tax": {"rate": "0%", "category": "E", "label": "exempt", "grounds": "§ 4 Nr. 14 UStG"}},
    {"kind": "discount", "name": "Seasonal", "amount": "5%"},
    {"kind": "surcharge", "name": "Admin fee", "amount": "30.00", "tax": "19%"},
    {"kind": "prepayment", "amount": "100", "name": "Anzahlung", "date": "2026-01-01"}
  ]
}
```

Conventions:

- absent key = auto (inherit/default); `null` = none.
- money and quantities as strings; percent as "N%".
- tax as "N%", an object, or a preset string.
- date as ISO "YYYY-MM-DD" or [start, end].
- unit as a module name, {display, code}, or free text.
- `custom` is passed through.
- Separate arrays (`modifiers`, `prepayments`) are an equivalent alternative.

The prototype (`fast/rows.typ`) implements exactly this. Parsers: `to-amount` (regex-gated `eval("19%")`, else `decimal(str)`), `to-date` (split on "-"), `to-unit` (`dictionary(unit-module)` lookup), `to-tax`. `env-of(ctx)` extracts and resolves the cascade once. `item-signal(env, row)` builds the minimal ctx and calls `calculate-item-data`. Bundles use `calculate-modifier` + `calculate-bundle`. One `motif(measure: (ctx, _) => (frames-of(ctx, env-of(ctx), data), none), none)`.

---

#### 6. Measurements (typst 0.15.1 unless noted)

| N items | motif loop | fast path | eval motif → fast |
| ------- | ---------- | --------- | ----------------- |
| 1       | 0.32 s     | 0.31 s    |                   |
| 50      | 1.24 s     | 0.86 s    |                   |
| 200     | 4.43 s     | 2.85 s    | 1894 → 689 ms     |
| 500     | 12.60 s    | 6.80 s    | 5468 → 1522 ms    |
| 1000    | 30.3 s     | 17.2 s    |                   |

Remaining time after the fast path is layout: 3 iterations, with the table's keep-together `fits()` measure per entry (table.typ:1120-1138) and the table itself.

Per-call costs: closure call with full ctx 21.9 µs, with locale 15.6 µs, with a small dict 3.4 µs. format-item via mutator.batch ≈ 0.6–1 ms per item vs a plain dict merge ≈ 0.04 ms.

---

#### 7. Recommendations for the panel

1. Add a new hydration component (name TBD) that emits frames. It is an extension only and can be mixed with static items. Make the data path and `item()` share pure resolver functions, refactored out of the inline scope closures (internal, no API change).
2. Keep per-row function arguments small and pass-independent, so the second loom pass is memo hits.
3. Validate data against a schema with path-specific errors, and cap nesting depth at 9 or less, or fix `collect-signals(depth: 10)`.
4. Optional internal speed-ups: replace the mutator.batch in format-item and in item scope with plain dict construction, and make keep-together cheaper or configurable in the theme.
5. `typst eval` (0.15) plus the pure functions makes a cheap "compute/validate only" CLI path for phase 1 and phase 2.
