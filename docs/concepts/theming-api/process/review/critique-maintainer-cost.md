# Critique of concept draft 1 through the solo-maintainer cost and simplicity lens

Critic key: `maintainer-cost`. Working copy: `scratchpad/crit-maintainer-cost/` (a copy of `proto-synthesis`;
the only engine change is in `src/theming/resolve.typ`, described in F3). Repro files are in `tests/crit/`.
Evidence tags: **VERIFIED** (reproduced with typst 0.15.1), **SOURCE** (read in code or docs), **REASONED** (argument only).

## TL;DR

The architecture is right: a layout as data, a parts registry, a small token tier and one strict patch engine.
Decision 2 is met by the **mechanism** (a layout dict plus the owned frame), not by the number of layout or
preset values that ship. What the draft gets wrong for a solo maintainer is **scope and schedule**:

1. The roadmap puts a **rewrite of the 1,391-line table and totals renderer** (M3) and 5 unbuilt or unverifiable
   extras inside the API lock. My estimate is **40–60 maintainer-days** before 0.5.0. A lean plan fits in
   **20–29 days**.
2. **M1 "engine behind a shim" is wasted work.** Typst packages cannot publish `0.5.0-dev` or `0.5.0-rc` (VERIFIED:
   `` `0-rc` is not a valid patch version ``), so M1–M5 never reach users. The shim over letter-pro can only honour
   `form`, `font`, the marks, `margin` and `footer`, and it is deleted in M2.
3. **The fixpoint resolver is unsound in both directions** (VERIFIED). An acyclic chain of depth 6 is reported as a
   cycle, and a pure cycle (`text: t => t.colors.muted`, `muted: t => t.colors.text`) resolves **silently** to the
   placeholder: black, or **0pt** for sizes. A fix of about 15 lines keeps the fixpoint and makes it sound (verified,
   with no measurable cost). Replacing it with a "single pass plus cycle guard" is not possible in Typst, because a
   derivation `t => ..` receives a plain dict, so accesses cannot be intercepted.
4. **Freeze less.** `themed`, row capture, `adjust`, `from-data` (with alias strings), `checks`, `isolate`/`float`
   reserved zones, the SN/NF/UK layouts, the `minimal` preset and the table rewrite are all **additive**. Moving
   them to 0.5.x costs nothing at the API lock.
5. The draft **promises code that does not exist**: rename aliases (0 lines), `sn-010130-left`, `nf-z-11-001` and
   `uk-c5` (not in `layouts.typ`). It also freezes the option **helper names** while calling the options
   provisional.

## 1. Measurements

### 1.1 Lines per module (`wc -l`; "code" = non-blank, non-comment; branches = `if|for|while|and|or` tokens)

| Module                         |     Lines | Code | Branches | Panics | Notes                                                                                    |
| ------------------------------ | --------: | ---: | -------: | -----: | ---------------------------------------------------------------------------------------- |
| `utils/patch.typ`              |       160 |  103 |       46 |      7 | shared merge; good value per line                                                        |
| `theming/schema.typ`           |       153 |  130 |       10 |      0 | data; cheap                                                                              |
| `theming/validate.typ`         |       181 |  158 |   **86** | **20** | **hot spot #1** (roles, overlap, assets, contrast, paper table)                          |
| `theming/frame.typ`            |       217 |  186 |   **52** |      2 | **hot spot #2**; reserved zones and footer relocation = lines 133–140 and 201–216        |
| `theming/resolve.typ`          |        93 |   71 |   **47** |      3 | fixpoint plus type checks; 105 lines after the F3 fix                                    |
| `theming/build.typ`            |       133 |  102 |       19 |      6 | `build-theme`, `finalize`, `adjust`, `scope-theme`                                       |
| `theming/layout-ops.typ`       |        79 |   68 |       21 |      8 | a **second** merge engine, for regions                                                   |
| `theming/data.typ`             |        82 |   64 |       24 |      5 | `from-data`: regex coercion plus alias strings                                           |
| `theming/custom.typ`           |       130 |   70 |        8 |      3 | ~25 helpers; every key is written 2× in the helper (plus 1× in the schema)               |
| `theming/layouts.typ`          |       138 |  117 |        1 |      0 | **7 layouts, not the 10 listed in §3.3**                                                 |
| `theming/presets.typ`          |        33 |   24 |        1 |      0 | looks are about 8 lines each                                                             |
| `theming/color.typ`            |        41 |   24 |        8 |      0 |                                                                                          |
| `theming/access.typ` (sealing) |        15 |   10 |        4 |      0 | sealing is **10 lines**                                                                  |
| `theming/scope.typ` (`themed`) |        17 |   13 |        2 |      1 |                                                                                          |
| `theming/parts/frame.typ`      |       178 |  152 |       32 |      0 |                                                                                          |
| `theming/parts/body.typ`       |       117 |  101 |       11 |      2 | **adapts the old 1,779-line renderers** (`src/themes/components/line-items/*`)           |
| **Total new**                  | **1,926** |      |          |        | draft §9 says 1,767 ("about 700 parts and frame"); the measured parts plus frame are 512 |

Integration diff against the repository (`diff -r --strip-trailing-cr`): components 79 changed lines, `invoice.typ`
28, `logic` 7, `themes` 11, `locale` **0**. The patch engine is **not** adopted by locale in the prototype (the draft
admits this in §10). The old theme code is **2,484 lines**. Of those, 1,779 are table, totals and global-info
renderers that the prototype keeps and calls from `parts/body.typ`.

### 1.2 Duplication and speculation found in the prototype (SOURCE)

- **Region normalisation is done twice.** `region-defaults + r` appears at `validate.typ:82` and `frame.typ:114`.
- **Required parts are listed in three places**: `validate.typ:8` (`required-parts`), `validate.typ:10`
  (`required-roles`) and `frame.typ:48` (`_required-roles`). The body side uses a separate `required:` flag
  (`parts/body.typ:15`).
- **There are two merge engines.** `patch.typ::merge` is strict and deep. `layout-ops.typ:291` merges regions shallowly
  with `existing + rv`, so `region(text: ..)` and `region(inset: ..)` replace instead of fold. That breaks the
  §4.2 rule "strict at every depth".
- **A paper table of 4 entries duplicates Typst's own list** (`validate.typ:15`). VERIFIED:
  `paper: "a3"`, `"a6"` and `"us-executive"` each panic with ``theme::layout::paper `a3` has no known size`` (repro:
  `tests/crit/paper.typ --input paper=a3`). This is friction for decision 2, and it creates a list to maintain.
- **Speculative promises with no code:**
  - rename aliases (`grep -i alias` finds only `from-data`);
  - `sn-010130-left`, `nf-z-11-001` and `uk-c5`;
  - the "schema tables generated from `schema.typ`" docs generator;
  - the QR-bill component (a placeholder slip).

### 1.3 Performance (VERIFIED, this machine, noisy)

| Run                                                                                  | ms                                                                                       |
| ------------------------------------------------------------------------------------ | ---------------------------------------------------------------------------------------- |
| `bench-150`, sealed (3 runs)                                                         | 1254 / 1267 / 1268                                                                       |
| `bench-150`, `--input ip-seal=0` (3 runs)                                            | 1916 / 1922 / 1935 (+52 %)                                                               |
| `bench-150`, original vs F3-fixed resolver (4 runs each)                             | 1508–1914 vs 1522–1686, no measurable difference                                         |
| `tests/crit/bench-themed.typ`: 30 groups, 15 wrapped in `themed(row(fill))`, vs none | 1087–1273 vs 1414–1691, inside the noise; row capture renders correctly (`out/bt-2.png`) |

## 2. Findings (blockers and majors first)

### F1 · major · The roadmap does not fit a solo maintainer, and M3 is not theming work (REASONED + SOURCE)

§12 puts seven milestones before the lock. M3 ("table/totals renderers read tokens, drops 50 params") rewrites
`table.typ` (927 lines) and `totals.typ` (464 lines). The line-items view stays **provisional** anyway (§3.8 and
Appendix Q7), and the prototype already runs every body part over the old renderers (`parts/body.typ:5-9`). So the
rewrite is not needed to freeze anything.

My estimate, in focused maintainer-days, based on the prototype sizes and the repository's test and docs layout:

| M         | Draft scope                                                                 |                             Estimate | Main cost drivers                                                                             |
| --------- | --------------------------------------------------------------------------- | -----------------------------------: | --------------------------------------------------------------------------------------------- |
| M0        | patch.typ into locale, lang fix, metadata into root, 0.14 CI with benchmark |                                  4–6 | `locale/custom.typ` is 378 lines to port; CI timing gates are flaky (F9)                      |
| M1        | engine behind a shim                                                        |                                  6–9 | of which **2–3 days of shim code are deleted in M2** (F2)                                     |
| M2        | own frame, DIN, footer, page label, stationery, guards; letter-pro removed  |                                 7–10 | new `sender` keys (types, coercion, docs); `strings.document.page` in 5 languages; ref review |
| M3        | views v2, table rewrite                                                     |                            **10–15** | a rewrite of 1,391 lines, plus the regressions of issue-39 and issue-41                       |
| M4        | modern and minimal; US and digital; SN/NF/UK after mask checks              | 4–6, **plus an external dependency** | buying SN 010130 / NF Z 11-001 or getting the masks (Appendix Q3)                             |
| M5        | `themed`, `from-data`, PDF/A guards, contrast, `adjust`                     |                                  4–6 |                                                                                               |
| M6        | 6 docs pages, schema-table generator, registry                              |                                  5–8 | new tooling                                                                                   |
| **Total** |                                                                             |                            **40–60** | at a few days per month, that is most of a year                                               |

**Fix:** adopt the lean plan in §4 (20–29 days) and move M3's table rewrite to 0.5.x or 0.6. Keep only the
compliance parts of M3 in 0.5.0:

- notices outside the composite;
- zero-tax filtering in measure;
- the EPC payload in measure (already built in `components/bank-details.typ`).

### F2 · major · M1's "engine behind a shim over the old DIN document" is wasted work (VERIFIED + SOURCE)

- **Nothing can ship.** A local package with version `0.5.0-rc` fails with
  ``error: `0-rc` is not a valid patch version`` (repro: `tests/crit/ver.typ --package-path tests/crit/pk`). The
  "0.5.0-dev" and "0.5.0-rc" labels in §12 are therefore git branches only. "Each milestone shippable" holds only
  for 0.4.3 and 0.5.0.
- **The shim has nothing to map to.** `themes/DIN-5008/din-5008.typ` accepts `form`, `font`, `hole-mark`,
  `folding-marks`, the row colours, `margin` and `footer`, and `document.typ:161` forwards them to letter-pro's
  `letter-generic`. A shim can honour about 6 of the new layout fields. It must silently ignore or reject regions,
  stationery, `pages`, non-A4 paper and custom parts. Meanwhile the validator would check a region geometry that is
  not rendered, so the identity guard and the overlap lint would guard fiction.
- **"No visual churn" in M1 has no value on its own.** M2 changes the refs anyway, and no user sees M1.

**Fix:** merge M1 and M2 into one "engine + own frame" step. The prototype's `frame.typ` (217 lines) already
exists. Delete the shim from the plan and save 2–3 days.

### F3 · major · The fixpoint resolver misses real cycles and reports false ones; §4.3 and §11 are wrong (VERIFIED)

The draft (§4.3) claims that resolution "panics if it does not settle" and that "cycles are detected".

- **False positive.** `tests/crit/chain.typ --input n=6` builds an acyclic chain
  `text → muted → subtle → rule → label → mark → #123456`. Result:
  `panicked with: theme::tokens: derivations do not settle after 6 rounds (a derivation cycle ...)`.
  A chain of depth 5 passes. The cap of 6 rounds is arbitrary: propagation needs depth + 1 rounds.
- **False negative (worse).** `tests/crit/cycle.typ` sets
  `colors(text: t => t.colors.muted, muted: t => t.colors.text)` and `sizes(base: t => t.sizes.large, large: t => t.sizes.base)`.
  It compiles **without error** and gives `text=luma(0%) muted=luma(0%) base=0pt` (`out/cycle.png`). A pure cycle
  copies the round-0 placeholder around, so it looks settled. `base = 0pt` produces invisible text. The prototype's
  cycle test (`tests/errors/err.typ` case 10) passes only because it uses `.lighten(5%)`, which keeps changing the
  value.

**Simpler alternative?** A "single pass with lazy functions plus a cycle guard" needs to intercept `t.colors.x`
lookups. Typst dicts have no getters, and a derivation receives a value, not a resolver. Without declared
dependencies (another expression language, which the draft rightly rejected), only iteration works. **Keep the
fixpoint and make it sound:**

1. Cap the rounds at _(number of derivation leaves + 1)_. An acyclic chain can never be longer than that.
2. Run the fixpoint twice, with two different placeholder sets (black/white, 0pt/1pt, and so on). If the results
   differ, they depend on the placeholder, which only happens in a cycle. Then panic.

I built this in `crit-maintainer-cost/src/theming/resolve.typ` (+12 lines; the text is also in
`tests/crit/new-resolve.typ.txt`). Results:

- chains n=6 and n=7 pass;
- `cycle.typ` panics with `derivations form a cycle`;
- err case 10 still panics;
- `coverage.typ` passes;
- bench-150 shows no measurable change.

Also delete the §11 bullet "self-consistent cycles are accepted", which becomes false.

### F4 · major · The freeze surface is larger than a solo maintainer can carry; most extras are additive (REASONED)

§5.2 freezes, or ships as experimental, about 25 mechanisms. Every frozen mechanism costs docs, a test and a
permanent compatibility promise. Every experimental mechanism still costs issues and support. The mechanisms below
do not affect the shape of anything frozen, so they can arrive in 0.5.x without a break: `themed`, `row` capture,
`adjust`, `from-data`, `checks`, `isolate`/`float`, `qr-bill`, the SN/NF/UK layouts, `minimal`, `build-theme` as an
export, and view v2. The ranked cut list is in §3.

**Fix:** freeze the core listed in §4 and label everything else "0.5.x".

### F5 · major · §3.3 lists layouts that do not exist and cannot be verified (VERIFIED)

§3.3 and §2.1 list 10 layouts. `src/theming/layouts.typ` defines 7: `din-5008-a/b`, `us-letter-10`, `a4-digital`,
`letter-digital`, `sn-010130-right` and `plain`. `sn-010130-left`, `nf-z-11-001` and `uk-c5` are not there. The SN
layout's own comment says its millimetres are "low-confidence (2003 source)" (`layouts.typ:102`).

Owning a layout means owning postal correctness (the draft's own §11 says so), and each layout needs one visual ref.
Decision 2 is already demonstrated without them: the third-party A5 sidebar receipt (`tests/third-party.typ`)
compiles from a plain dict.

**Fix:** ship `din-5008-a`, `din-5008-b`, `plain` and `a4-digital` as stable, plus `letter-digital` (one line,
`derive`). Ship `us-letter-10` as **experimental** (unverified against USPS). Move all SN/NF/UK layouts to 0.5.x, to
arrive through PRs together with their masks. PR #40's UK work is the model.

### F6 · major · Rename aliases are promised but have no code and create a permanent cost (VERIFIED)

§3.5 and §5.2 say that a renamed option "keeps its old path as an alias for one minor version" and that the validator
names both. `grep -rni "alias|rename" src/theming src/utils` finds no such mechanism, and §8 lists the hint as
unbuilt. The promise implies, for every rename:

- alias code in resolution;
- a hint in the validator;
- a test;
- a removal one minor later;
- region-level aliases, which the draft marks "not verified".

**Fix:** drop the promise. Define "provisional" as "may change in a 0.5.x minor, with a changelog entry and a
did-you-mean hint". The strict merge already produces that hint for free: a renamed key fails with "unknown key ...
Did you mean ...".

### F7 · major · Option helper names are frozen while the options are provisional (SOURCE)

§5.2 freezes the "helper names", and §2.5 includes `items-table`, `totals`, `title`, `logo`, `sender`,
`bank-details`, `page-number`, `continuation` and `row`. Those helpers are the options groups that §3.5 calls
provisional, and a helper's parameters are its option keys (`tests/coverage.typ` enforces that). Freezing the helper
freezes the options.

**Fix:** freeze the token, layout and parts helpers (`colors`, `fonts`, `sizes`, `weights`, `strokes`, `spacing`,
`page`, `margin` via `page`, `marks`, `stationery`, `region`, `part`, `wrap`, `replace`, `brand`). Mark the option
helpers provisional, together with their options.

### F8 · minor · The migration effort is smaller than the draft states (SOURCE)

In the repository:

- `grep -rn "themes\.blank"` finds **40 hits in 20 files**, all of which already pass sender and recipient, so the
  identity guard is satisfied;
- 40 test files reference `themes.` in some form;
- **there are 11 committed reference PNGs in 9 test directories** (`find tests -path "*/ref/*.png"`), not "~20".

Migration breaks down as:

- `sed s/themes.blank/theme.plain/` plus a namespace import fix: about 0.5 day;
- re-generating and reviewing the 11 PNGs: about 1 day;
- the registry: 2 rows in `docs/DOCUMENTATION.md:83-84`, and the `themes.blank` advice at `tests/TESTING.md:281`.

The real test cost is the **new** tests (see F10). Correct the §11 and M2 numbers.

### F9 · minor · Sealing: keep it, but move its benchmark out of CI (VERIFIED)

Sealing is 10 lines (`access.typ`) and saves about 34 % of compile time at 150 items: 1.26 s vs 1.92 s here. If
Typst ever hashes `metadata` eagerly, the failure is graceful: the compile gets slower, but no output is wrong. The
risk is therefore low. A **timing gate in CI** (M0), by contrast, is flaky on shared runners, and tytanic has no
timing assertions (the project's runner, `tests/TESTING.md:3`). So it would be a new custom script that fails at
random.

**Fix:** keep sealing internal. Keep the 0.14.0 compile job. Run the benchmark as a manual step on the release
checklist.

### F10 · minor · The look × layout matrix of 28 renders cannot be maintained under tytanic (SOURCE)

Tytanic requires one directory per test with a fixed `test.typ` (`tests/TESTING.md:46`). The prototype's matrix uses
`--input look= layout=`, which tytanic does not vary per test. Reproducing it means 28 test directories, or 28 refs
with `ref/`.

**Fix:** write one unit test that loops over presets × layouts with `theme.resolve-theme(..)` and asserts the look
invariants (the band survives, the required roles are hosted). That test runs no layout. Add one visual ref **per
shipped layout** (5) and one per shipped preset (2–3).

### F11 · minor · The paper validation rejects paper sizes Typst supports (VERIFIED)

See 1.2. The fix is cheap: if `paper` is a string that is not in the table, measure it once in the frame with
`context (page.width, page.height)` after `set page(paper:)`, and skip the overlap lint for it. Alternatively, copy
Typst's full paper list. That adds about 100 entries to maintain, so I do not recommend it.

### F12 · minor · Duplicated logic in validate, frame and layout-ops (SOURCE)

- Normalise regions once in `finalize` and store the normalised regions in the resolved theme.
- Keep one `required` table in `validate.typ` and import it in `frame.typ`.
- Let `layout-ops` call `patch.merge` per region field, so nested region dicts are strict too.

Together this saves about 25 lines and removes three places where the copies can drift.

### F13 · minor · `build-theme` as a public export is redundant (SOURCE + REASONED)

- The zero-import package path is `theme.minimal.with(pkg.patch, layout: pkg.layout)` (`tests/third-party.typ`). It
  never calls `build-theme`.
- A company theme is `#let company = theme.classic.with(..)`, as in P5.
- The only thing `build-theme` adds is the `name` in error messages.

**Fix:** keep it internal for the presets. Export `resolve-theme`, which package CI and unit tests need. Promote
`build-theme` in 0.5.x if anyone asks for it.

### F14 · minor · The docs plan (6 pages plus a generator) is new infrastructure (REASONED)

Today theming is covered by `docs/docs/api-reference/theme.md` (90 lines) and 2 registry rows.

**Fix:** write 3 hand-written pages:

1. overview and customisation (the ladder, `theme.custom`);
2. layouts and regions, including "write your own format", which is the decision-2 page;
3. parts and packages.

Write the schema tables by hand and keep them honest with the coverage test. Build the generator in 0.5.x.

### F15 · nit · The default `classic` preset prints the page label twice on pages ≥ 2 (VERIFIED)

`out/bt-2.png`: the continuation header shows "Seite 2 von 8" (`parts/frame.typ:134`), and the `page-number` footer
shows "Seite 2 von 8" as well. This drifts the default look further (Appendix Q10) and will draw issue reports.

**Fix:** either drop the label from `continuation`, or drop `page-number` from `classic`'s pages ≥ 2.

## 3. Cut list

Value covers users and compliance. Cost = implementation + lifetime maintenance. Both are scored 1–5. Ratio = value / cost.

| #   | Mechanism                                                                                | Value | Cost | Ratio | Recommendation                                | Rationale                                                                                                                                          |
| --- | ---------------------------------------------------------------------------------------- | :---: | :--: | :---: | --------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1   | `utils/patch.typ` strict merge (auto/none, `::` paths, did-you-mean, sides, templates)   |   5   |  2   |  2.5  | **keep-frozen, ship in 0.4.3**                | fixes the locale bugs; one engine for two APIs                                                                                                     |
| 2   | Lazy theme, `.with(..patches, layout:)`, named-argument panic, idempotent call           |   5   |  1   |   5   | **keep-frozen**                               | a few lines; removes the verified `.with` traps                                                                                                    |
| 3   | Layout as data + region schema + owned frame (letter-pro dropped)                        |   5   |  4   | 1.25  | **keep-frozen**                               | _this is decision 2_; unavoidable cost                                                                                                             |
| 4   | Region fields place / pages / geometry / parts / arrange / fill / text / brand / reserve |   5   |  3   |  1.7  | keep-frozen                                   | `arrange` functions stay experimental                                                                                                              |
| 5   | `stationery` (3 modes)                                                                   |   5   |  1   |   5   | keep-frozen                                   | the P2 business case; about 10 lines                                                                                                               |
| 6   | Token tier (35) + derivation from the seed                                               |   4   |  2   |   2   | keep-frozen                                   | **with the F3 fix**                                                                                                                                |
| 7   | Fixpoint resolver                                                                        |   4   |  2   |   2   | **keep, fixed** (F3)                          | a single pass with a guard cannot be built in Typst; the fix adds 12 lines                                                                         |
| 8   | Parts registry, `part()`, `wrap()`, wrap marker as a plain dict                          |   5   |  2   |  2.5  | keep-frozen                                   | the escape hatch that makes "any format" real                                                                                                      |
| 9   | Options tier (per part)                                                                  |   4   |  2   |   2   | keep-**provisional**, no aliases              | F6, F7                                                                                                                                             |
| 10  | Rename aliases                                                                           |   1   |  3   |  0.3  | **drop**                                      | no code; permanent cost; the did-you-mean hint covers renames                                                                                      |
| 11  | Sealing in `metadata`                                                                    |   3   |  1   |   3   | keep (internal)                               | measured −34 %; fails gracefully (F9)                                                                                                              |
| 12  | Identity guard (recipient/title roles, empty-output panic)                               |   5   |  1   |   5   | **keep-frozen**                               | § 14 UStG; about 25 lines                                                                                                                          |
| 13  | Overlap lint (window)                                                                    |   3   |  1   |   3   | keep (message not frozen)                     | 12 lines; only fixed first-page regions                                                                                                            |
| 14  | Notices outside the composite, EPC in measure, 0 % in measure                            |   5   |  2   |  2.5  | keep-frozen                                   | compliance core; the EPC part is already built                                                                                                     |
| 15  | Logo alt text + PDF-image-in-PDF/A guard + CMYK guard                                    |   4   |  1   |   4   | keep                                          | cheap; add the CMYK test                                                                                                                           |
| 16  | 25 `theme.custom` helpers + coverage test                                                |   4   |  2   |   2   | keep; option helpers provisional (F7)         | house idiom P6/P7; 30-line test                                                                                                                    |
| 17  | `brand()` macro                                                                          |   4   |  1   |   4   | keep-frozen                                   | rung 2 of the ladder                                                                                                                               |
| 18  | `replace()` marker                                                                       |   2   |  1   |   2   | keep                                          | 2 lines                                                                                                                                            |
| 19  | Marks with template re-hydration                                                         |   3   |  1   |   3   | keep                                          |                                                                                                                                                    |
| 20  | `resolve-theme`                                                                          |   4   |  1   |   4   | keep-frozen                                   | tests and package CI                                                                                                                               |
| 21  | `build-theme` export                                                                     |   1   |  1   |   1   | **internal**; 0.5.x if asked                  | F13                                                                                                                                                |
| 22  | `themed` scoped overrides                                                                |   3   |  3   |   1   | **defer to 0.5.x**                            | additive; interacts with loom scope, sealing and group guards                                                                                      |
| 23  | Row capture (`row.fill`)                                                                 |   2   |  2   |   1   | **defer to 0.5.x** (with `themed`)            | touches `components/group.typ`; only works inside `themed`                                                                                         |
| 24  | `adjust()`                                                                               |   2   |  2   |   1   | **defer to 0.5.x**                            | re-runs `finalize`/validate on each call; a wrapper can transform `view` or edit `ctx.theme.options` directly                                      |
| 25  | `isolate` / `float` reserved zones + footer relocation                                   |   2   |  4   |  0.5  | **defer to 0.5.x** with the QR-bill component | the most intricate frame code (float + query + relocation); the only consumer is an experimental SN layout                                         |
| 26  | `checks` group (min-contrast)                                                            |   2   |  2   |   1   | **drop as a group**; export `theme.contrast`  | no warning API means strict only; users get the same with `assert(theme.contrast(..) >= 4.5)` on `resolve-theme`; built-in presets stay CI-checked |
| 27  | `from-data` regex parser                                                                 |   3   |  2   |  1.5  | **defer to 0.5.x**                            | additive; document a 6-line `toml()` → `colors(primary: rgb(..))` recipe for 0.5.0                                                                 |
| 28  | `from-data` alias strings `"{colors.primary}"`                                           |   1   |  2   |  0.5  | **drop**                                      | a second expression language, which the draft itself rejects (decision 3)                                                                          |
| 29  | Layouts: din-5008-a/b, plain, a4-digital, letter-digital                                 |   5   |  2   |  2.5  | **ship stable**                               | the existing users plus the successor of `blank`                                                                                                   |
| 30  | Layout: us-letter-10                                                                     |   3   |  2   |  1.5  | ship **experimental**                         | unverified geometry                                                                                                                                |
| 31  | Layouts: sn-010130-right/-left, nf-z-11-001, uk-c5                                       |   3   |  4   | 0.75  | **defer to 0.5.x**                            | 3 of the 4 are unbuilt; they need purchased masks (F5)                                                                                             |
| 32  | Presets: classic, plain                                                                  |   5   |  1   |   5   | **ship frozen**                               | the default and the successor of `blank`                                                                                                           |
| 33  | Preset: modern                                                                           |   3   |  2   |  1.5  | ship experimental, 1 ref                      | shows that the theming system has range                                                                                                            |
| 34  | Preset: minimal                                                                          |   2   |  2   |   1   | defer to 0.5.x (or a docs example)            | extra refs and one more frozen name                                                                                                                |
| 35  | Look × layout matrix (28 renders)                                                        |   2   |  3   |  0.7  | replace with a resolve-level loop             | F10                                                                                                                                                |
| 36  | Views v2 + table/totals rewrite                                                          |   3   |  5   |  0.6  | **defer to 0.5.x / 0.6**                      | the line-items view stays provisional anyway (F1)                                                                                                  |
| 37  | Schema-table docs generator                                                              |   2   |  3   |  0.7  | defer                                         | F14                                                                                                                                                |
| 38  | 0.14.0 CI compile job                                                                    |   5   |  1   |   5   | keep (M0)                                     | decision 6                                                                                                                                         |
| 39  | Sealing timing gate in CI                                                                |   1   |  2   |  0.5  | drop; release checklist                       | F9                                                                                                                                                 |

## 4. The lean "0.5.0 must-ship" subset

**Frozen:** rows 1–8, 12, 14, 17, 20, 29, 32, 38 of the cut list:

- the patch engine;
- the lazy theme;
- layout, region and frame;
- stationery and marks;
- tokens with the sound fixpoint;
- parts with `part` and `wrap`;
- the identity and compliance guards;
- `brand`;
- `resolve-theme`;
- 5 layouts;
- 2 presets.

**Provisional:** the options and their helpers, with no alias promise. **Experimental:** `us-letter-10`, `modern`,
`arrange` functions and the overlap-lint wording.

**Decision 2 is still met:**

- any paper through `(width:, height:)` (and named Typst papers after F11);
- any window or zone as a region;
- any furniture as a custom part or content;
- any stationery mode;
- a third-party A5 layout as a zero-import dict (kept as a docs test).

The frame, not the list of presets, carries the claim.

**Lean roadmap** (maintainer-days):

| Release         | Scope                                                                                                                                                                                                                                                                      |                 Days |
| --------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------: |
| 0.4.3           | `utils/patch.typ` adopted by locale (the I-1/I-2/I-3 fixes), `lang` fix, `set document` + `pdf.attach` in root, 0.14.0 CI compile job                                                                                                                                      |                  4–5 |
| 0.5.0 step A    | engine: schema/resolve (F3)/build/validate/custom/layout-ops, error suite, coverage test                                                                                                                                                                                   |                  5–7 |
| 0.5.0 step B    | **own frame directly (no shim)**: frame parts, DIN A/B, plain, a4/letter-digital, stationery, legal footer blocks + `sender` keys, `strings.document.page` in 5 languages, identity guard; letter-pro and `src/themes/DIN-5008`, `base-theme/base.typ` and `blank` removed |                  6–9 |
| 0.5.0 step C    | body parts over the existing renderers, notices outside the composite, 0 % and EPC in measure, asset guards, `modern` (exp.), `us-letter-10` (exp.)                                                                                                                        |                  3–4 |
| 0.5.0 step D    | test migration (40 sed hits, 11 refs), new tests (resolve matrix, 5 layout refs, 3 stationery refs, compile-fail suite), fix F15                                                                                                                                           |                  2–3 |
| 0.5.0 step E    | 3 docs pages, registry rows, thumbnail                                                                                                                                                                                                                                     |                  4–6 |
| **0.5.0 total** |                                                                                                                                                                                                                                                                            | **20–29** (vs 40–60) |

**Moves to 0.5.x, all additive:**

- `themed` + `row`;
- `adjust`;
- `from-data` (without alias strings);
- reserved zones (`isolate`/`float`) + the QR-bill component + the SN layouts;
- NF/UK layouts through PRs with masks;
- `layout.for-region`;
- `minimal`;
- a public `build-theme` if requested;
- the docs generator;
- the table/totals rewrite with view v2 (or 0.6);
- the DTCG adapter.

**Dropped:** rename aliases, `from-data` alias strings, the `checks` group (replaced by the exported
`theme.contrast`), and the CI timing gate.

## 5. Reproductions (in `scratchpad/crit-maintainer-cost`)

```
typst compile --root . --input n=6 tests/crit/chain.typ out/chain.pdf    # original resolver: false "cycle" panic
typst compile --root . tests/crit/cycle.typ out/cycle.png                 # original resolver: silent black / 0pt
typst compile --root . tests/crit/paper.typ --input paper=a3 out/p.pdf    # paper table rejects a3/a6/us-executive
typst compile --root . --package-path tests/crit/pk tests/crit/ver.typ out/v.pdf   # `0-rc` is not a valid patch version
typst compile --root . --input themed=1 tests/crit/bench-themed.typ "out/bt-{p}.png"  # row capture; duplicate page label
typst compile --root . --input ip-seal=0 tests/bench-150.typ out/b.pdf    # unsealed timing
```

To see the original behaviour of the first two, copy `tests/crit/*.typ` into a fresh copy of `proto-synthesis/` and
run them there. The copy in `crit-maintainer-cost/` carries the fixed resolver (the original results are quoted in F3).
