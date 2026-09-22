# Verdict: the maintainer lens (solo implementer, frozen API)

Judge: maintainer. The question I asked of each proposal: can one person with limited time build this on loom 0.1.1 and Typst 0.14, ship it in steps, and still be comfortable with it after v0.5.0 is locked?

I read all four proposals in full, all seven research reports, and the prototype sources. I also ran my own experiments in `scratchpad/proto-judge-maintainer/` (copies of the four prototypes plus the research baseline):

1. **A cross-prototype benchmark.** The same invoice body (N items + 1 group + payment goal + bank details + signature, default theme of each proposal) was compiled on typst 0.15.1. Files: `*/jbench-{10,60,150}.typ`.
2. **A stress test.** I added a brand-immune reserved QR-bill zone on the last page to tokens-first, the proposal that had not prototyped it. Files: `tokens-first/jswiss.typ`, frame patch in `tokens-first/src/theme/frame.typ`, output `out/tf-swiss-2.png`.
3. **An output review.** I inspected the Swiss outputs of structure-first (`out-ch-*`, `out-chshort-1`), tokens-first and locale-symmetry.

---

## 1. Weights (my lens)

| Criterion                           | Weight |
| ----------------------------------- | ------ |
| feasibility_typst_loom              | 15     |
| stability_freezability              | 15     |
| maintainer_effort                   | 15     |
| compliance_safety                   | 10     |
| any_format_flexibility              | 10     |
| testability_docs                    | 10     |
| consistency_with_package_philosophy | 8      |
| customization_ladder_no_cliffs      | 7      |
| simple_case_ergonomics              | 5      |
| third_party_ecosystem               | 5      |

Total = Σ(score × weight) / 100.

---

## 2. Measured facts that change the picture

### 2.1 Performance is an implementation issue, not an API issue, but three of four prototypes have it

Minimum of 6 runs at N = 150, typst 0.15.1, Windows. Smaller N is noisier; the median of 3 is given in the second column.

| Prototype                                 | N=10 (median) | N=60 (median) | N=150 (min of 6) | vs 0.4.2 at 150 |
| ----------------------------------------- | ------------- | ------------- | ---------------- | --------------- |
| 0.4.2 baseline (letter-pro)               | 473 ms        | 734 ms        | 1173 ms          | –               |
| tokens-first (trees sealed in `metadata`) | 543 ms        | 759 ms        | 1190 ms          | **+1.5 %**      |
| user-first                                | 525 ms        | 861 ms        | 1368 ms          | +17 %           |
| structure-first                           | 499 ms        | 846 ms        | 1443 ms          | +23 %           |
| locale-symmetry                           | 636 ms        | 869 ms        | 1484 ms          | +26 %           |

The fixed cost at N = 10 is similar everywhere. The **per-item slope** is about 25-35 % steeper in the three designs that keep the theme as a plain dict in ctx. This matches the loom cost model (about 20 ns per ctx entry per closure call, `loom-capabilities.md` §3.6) and tokens-first's own finding: "+280 ms" plain versus "+15 ms" sealed.

Page count differs slightly: locale-symmetry's new table renderer produces 7 pages instead of 9, which _flatters_ it, so its per-item cost is if anything understated.

Consequences:

- Structure-first's claim of "+~7 %" and locale-symmetry's "~550 vs ~490 ms" were measured on small invoices. They do not hold at batch sizes. The contribution guide makes rendering speed an acceptance criterion.
- Sealing is a pure internal detail, so **any backbone can adopt it**. It rests on observed lazy hashing of content values, and nobody has checked that on 0.14.0. It needs an explicit 0.14 CI check. The loom nice-to-have is an official "opaque ctx value".

### 2.2 The reserved last-page zone is about 15 lines in any design, but a list-driven layout makes it user-expressible

Tokens-first lists `geometry.reserve` as "Not prototyped". I added it to my copy:

- `reserve: (last-bottom: 0mm)` in the base geometry;
- a `place(bottom + left, float: true)` block of height `r - margin.bottom` after the body;
- footer suppression on the last page.

It worked on the first compile (`out/tf-swiss-2.png`): the slip sits at 192 mm on the last page, the footer is suppressed there, and a 2-page invoice moves the slip correctly. Structure-first's version is the same mechanism (`frame.typ`, the `r.float` branch) and it also works (`out-chshort-1.png`: slip on the same page; `out-ch-2.png`: slip alone on page 2).

The test also surfaced problems that **every** proposal leaves open:

1. **Fold marks paint into the regulated zone.** In my TF run the 198 mm fold mark sits inside the slip. Structure-first only avoids this because its Swiss layout sets `marks: none`. The reserve must also suppress marks, stationery and background inside the zone.
2. **The footer is simply dropped on the last page.** The same goes for structure-first's `pages: "not-last"`. On a 1-page invoice with a slip, a § 35a legal footer disappears completely. A German GmbH invoicing a Swiss customer in CHF hits exactly this case. The frame needs a rule such as "footer moves into the flow above the reserved zone", or a validation error.
3. **Nobody said how a body component (`#qr-bill(..)`) gets its output into a frame zone.**
   - Structure-first makes the slip a _frame part_ hosted by a region, with data from the frame view.
   - Tokens-first, locale-symmetry and user-first call it a "core component" but do not show the plumbing.
   - The frame-part route is the only one that works with loom's lifecycle, because the frame is drawn last and sees root's fresh ctx.

So the feasibility difference is small. What differs is **who can express it**:

- In structure-first a user or third party writes a region.
- In tokens-first, locale-symmetry and user-first it is a hard-coded scalar or list that the maintainer extends.

### 2.3 Compliance gaps I found in the prototypes

- **structure-first:** `compliance-parts = ("notices", "totals", "bank-details")` (`validate.typ:5`). Nothing checks that the layout hosts `recipient` or `sender` anywhere. `region("address", none)` or a third-party layout without a recipient region silently drops the legally required recipient address. The fix is cheap: validate that the resolved layout references a required-parts set.
- **structure-first:** the frame view passes `totals: ctx.global` (`frame.typ:frame-view`). That freezes an internal ctx key into the public frame contract, which contradicts its own "ctx.global becomes internal".
- **user-first:** in its own words, notes, zero-tax suppression and the EPC payload "still live inside renderers in the prototype". Its compliance guarantees are therefore still on paper.
- **tokens-first:** `core-notes` is appended by the component _after_ the line-items part. This is the strongest and cheapest guarantee because no emptiness heuristic is needed. I want this in the synthesis.

---

## 3. Per-proposal verdicts

### 3.1 structure-first: backbone candidate (7.30)

**What works.** It is the only design where "any format" is data a user can write:

> "`place`, `x|right`, `y|bottom`, `width`, `height` ... `pages: "first" | "rest" | "last" | "not-last" | "all"` ... `parts: ("logo", "sender")`, in reading order"

The 12 compiled layouts are backed by real outputs. This includes the A5 sidebar receipt, which the other three cannot express without a frame override:

- locale-symmetry says "must wait for an experimental `parts.page` escape hatch";
- tokens-first says "Beyond them you override a part ... or ... the whole `frame`".

**Stress test.**

- DIN 5008 A is 20 lines of data (§3.7). The address split into `rows: (17.7mm, 27.3mm)` is exactly the letter-pro geometry.
- Swiss right window: `right: 12mm` anchoring is the right primitive because Swiss and French windows are specified from the right edge. The QR zone is a region with `float: true, isolate: true`.

**Hacks the stress test exposed.**

- `pages: "last"` on a `place: "after"` region is meaningless, since after-regions are always on the last flow page. The selector semantics differ per `place`.
- `din-5008-b = din-5008-a + (...)` uses hand-nested `+` because `layouts.derive` is "specified, not prototyped". Users will copy that idiom and break nested regions.
- The footer on the reserved page is dropped (see §2.2).
- Marks were avoided rather than handled.

**What I would regret freezing.**

- The frame view as specified, including `totals: ctx.global`.
- `options(name, ..fields)` with string part names. Validated at resolve time, but no autocomplete and it looks less like the house style than typed helpers.
- The named `tokens:/options:/parts:` shorthands on the lazy theme. They are replaced wholesale by a second `.with(...)`, which is the trap user-first documented. Only `layout:` should be named, because it is intentionally a swap.
- The design owns a small layout engine: fixed, before, after, header, footer, background and foreground, plus `reserve` and `float`. Its z-order bugs were found during prototyping ("The first z-order design put page-1 'all' overlays under the body"). That is maintenance forever, but it replaces letter-pro, which also had to be owned anyway.

**Tokens are too thin.** Only 10 colour roles are derived (`on-primary`, `surface`). R3 (whole palette from one seed) is only half met. This needs the tokens-first graft.

**Roadmap.** It is the most honest one. M2 ships the new API "without visual churn" behind a shim over the old DIN document. M3 is the only big visual diff. M5 layouts are pure data and user-contributable (PR #40 becomes a layout).

### 3.2 tokens-first: best engine, wrong centre (6.88)

**What works.**

- The strict merge engine: sides folding (`header-inset: (y: .8em)` keeps x), templates for `none` groups, dotted keys, arrays replace.
- Validation messages are the best of the four (`unknown token \`table.header-fil\`. Allowed keys in \`table\`: ...`).
- Sealing is the only prototype with baseline performance (§2.1).
- `core-notes` sits outside the part.
- A rename-alias mechanism for provisional tokens: "the old path simply becomes `"{new.path}"`". This is the one idea in all four proposals that makes a large frozen surface _survivable_.
- Third-party packages are plain dicts with `$op` descriptors and need no import.

**What I would regret freezing.**

- "About 190 tokens is a large learning surface", even with only ref and semantic (~60) formally frozen. Every enum value is a code path owned forever:
  - `letterhead.arrangement: "subject-left" | "logo-left" | "band" | "centered"`
  - `bank.layout: "side" | "below" | "boxed"`
  - `geometry.references: "line" | "info-block"`

  The proposal admits "a new composition needs a part or frame override". This is the enum treadmill: every new layout request becomes a new frozen enum value.

- A second expression language (`"{alias}"` plus `tint/shade/mix/on/legible/scale/times/stroke-of/pick/derive/replace`) with lazy recursive resolution and a cycle guard. For a Typst user, `t => t.color.primary` does the same with zero new concepts. The descriptors earn their keep only in TOML/JSON.
- The `..named` DSL helpers trade away autocomplete and per-parameter docs ("give up per-parameter autocomplete and doc comments in exchange for zero schema drift"). Locale-symmetry's coverage test solves drift without that trade.

**Stress test.**

- DIN: fine; it compiled.
- Swiss: `x: 118mm` instead of right-anchoring works, but it is paper-dependent.
- Reserve: trivially added (§2.2).
- Hack: "modern on DIN geometry ... overflows" (their own `out-themed-1.png`). Tokens cannot measure content and the zone set is fixed.

**Roadmap.** Incremental and credible. M1 keeps letter-pro behind tokens, M2 is the frame. M6 (table rewrite) is where the 50-parameter renderer finally dies. The same holds for everyone.

### 3.3 locale-symmetry: best consistency argument, worst freeze profile (6.49)

**What works.**

- `utils/patch.typ` shared with locale, which fixes three verified locale bugs (I-1 array idiom, I-2 panic, depth-2 merge). For a solo maintainer this is the single highest-value first step in any proposal: M0 ships user value before the theme API exists.
- The finding that schema _objects_ `(defaults, types, hydrate)` must be injected, not imported, so an older package validates against newer types. That is a real forward-compat trap, and they verified it across two package versions.
- The coverage test "calls every helper with every key".
- `notes` emptiness panic, verified.

**What I would regret freezing.**

- "`<style>-<layout>` scales multiplicatively (4 × 9 = 36 names)". Every preset name is frozen API and a docs row. `build-theme(style, layout)` already covers combinations.
- "Two parallel schema trees ... each key is written three times".
- "Derivations may only reference keys defined earlier in schema order". That is an invisible ordering rule users trip over.
- The layout as "a function of the final style". Its only demonstrated use is marks painted in the brand colour, which a lazy token reference also does. It adds an API shape without a use case.
- "The core frame is not replaceable". That directly contradicts maintainer decision 2 (any layout). The sidebar or address-in-sidebar class of layouts is out.

Third-party packages `#import "@preview/invoice-pro:0.5.0": themes` to call `build-theme`/`wrap`. It works across versions only as long as the wrap-marker format stays stable, which is another frozen internal.

**Stress test.**

- DIN: fine.
- Swiss: `reserved.last-bottom` is unbuilt. `furniture.footer` has no "not-last" value, so collision handling is implicit core magic.
- The prototype's new totals renderer shows overlapping text (`out/swiss-1.png`, "Gesamtbetrag" on the rule).

### 3.4 user-first: best five-minute UX, least aligned with the house (6.41)

**What works.**

- `theme.classic.with(logo:, color:, font:)` is the shortest simple case.
- The verified `.with` finding ("`.with` replaces a dict-valued named argument wholesale") is correct and important for _everyone_. It argues for positional patch arrays, which three designs already use.
- "did you mean" hints.
- `medium` as a mode that "wins over styling", found by testing.
- The `assets: p => image(p)` loader closure, verified across a package boundary. This is the best 0.14-compatible answer to logo paths in brand files.
- `it.default(..overrides)` re-parameterisation is an elegant middle rung.

**What I would regret freezing.**

- "29 named knobs" in every preset signature. Every new part becomes a new named parameter of every preset.
- A new single-argument `it =>` part signature. It departs from the house ctx-first `(ctx, view)` convention (api-philosophy P12) and freezes `it.tokens`, `it.brand`, `it.geometry`, `it.locale` and `it.opts`.
- An explicit rejection of the locale-style DSL ("a second vocabulary"). That contradicts decision 3.
- The singular `theme` namespace. It is defensible, but it is churn.
- "Two ways to load a brand file".
- `kinds` frozen before document kinds exist.

**Compliance.** It is the least proven: notes and EPC are still in renderers (M4).

**Stress test.** Swiss "kept on DIN until SN geometry is verified". That is a sensible caution, but the reserve zone is unbuilt.

---

## 4. Scores

| Criterion (weight)                      | tokens-first | structure-first | locale-symmetry | user-first |
| --------------------------------------- | ------------ | --------------- | --------------- | ---------- |
| any_format_flexibility (10)             | 6            | **9**           | 5               | 6          |
| simple_case_ergonomics (5)              | 7            | 7               | 7               | **9**      |
| customization_ladder_no_cliffs (7)      | 7            | **8**           | 6               | 8          |
| consistency_with_package_philosophy (8) | 8            | 8               | **9**           | 5          |
| feasibility_typst_loom (15)             | **8**        | 7               | 7               | 7          |
| compliance_safety (10)                  | **9**        | 7               | 8               | 6          |
| stability_freezability (15)             | 6            | **7**           | 5               | 5          |
| maintainer_effort (15)                  | 5            | **6**           | 6               | 6          |
| third_party_ecosystem (5)               | **9**        | 9               | 6               | 8          |
| testability_docs (10)                   | 6            | **7**           | 7               | 7          |
| **Weighted total**                      | 6.88         | **7.30**        | 6.49            | 6.41       |

**Ranking:** structure-first > tokens-first > locale-symmetry > user-first.

---

## 5. Synthesis recommendation

### Backbone: structure-first

It provides the page master as data, open named regions hosting parts, the flat parts registry with `(ctx, view)` plus wrap-with-`inner`, the core-owned frame, and a small semantic token layer.

The reason is the freeze profile: open-ended layout expressiveness comes from a _small, general_ schema rather than from growing enums and preset names. New needs arrive as data (layouts, regions, parts) or as additive tokens, not as new frozen vocabulary.

### Graft from tokens-first

1. **The merge engine semantics:** strict at every depth with full path plus allowed keys, sides folding for inset and margin, templates for groups that are `none`, dotted keys in raw patches, arrays replace, `replace(v)` marker.
2. **Sealing** of the resolved and unresolved trees in `metadata` (internal only). Add a 0.14.0 CI benchmark gate.
3. **`core-notes` appended by the component outside the part**, replacing structure-first's emptiness check as the primary guarantee (keep the check as a secondary guard for custom `notices` wrappers). Also: EPC QR built by core with a size clamp, and the mandatory-parts refusal.
4. **The tiered token idea, trimmed:**
   - a frozen _semantic_ tier (color/font/size/weight/space/stroke roles, about 40 leaves, including `on-primary`, `accent-text` via `legible`, `surface-alt` via OKLab tint);
   - per-part `options` as the provisional component tier, with the **rename-alias mechanism** (a renamed provisional key keeps an alias for one minor version);
   - no `ref` tier in 0.5.0. Seeds are the semantic `primary` and `accent`.
5. **Validation catalogue:** the logo-alt requirement, the contrast lint with `"strict"`, and the planned PDF/A guards (CMYK, `.pdf` image source when `zugferd != none`).
6. **`themes.resolve-theme(theme, env:)`** for unit tests and third-party CI.
7. **`from-data`** with a regex length parser, no `eval`. Alias strings `"{color.primary}"` are allowed **only in data files** and converted to lazy functions at load. Do **not** freeze the `$op` descriptor language in 0.5.0; keep it experimental inside `from-data` if at all.

### Graft from locale-symmetry

1. **`utils/patch.typ` shared with locale, shipped first** (M0, 0.4.3). It fixes the locale DSL bugs and proves the patch semantics before the theme API is locked on them.
2. **Inject schema objects** (defaults and types) from the running version, never import them in the factory.
3. **The helper/schema coverage test** instead of `..named` helpers. The DSL keeps typed named parameters (autocomplete, native `unexpected argument`), which structure-first already has for colors, fonts and sizes.
4. **"Compliance lives in core" table and `themed` re-resolving on the unresolved source.** Both proposals have it; keep locale-symmetry's wording in the docs.

### Graft from user-first

1. The **`assets: p => image(p)` loader** for brand files. It keeps the 0.14 minimum and avoids `path()`.
2. The **"mode wins over styling"** rule for `stationery: "pre-printed"`, which structure-first already approximates with `brand: true` regions. Adopt user-first's test case.
3. **"Did you mean" hints** in unknown-key errors.
4. The **`.with` wholesale-replace rule** as a design constraint: drop structure-first's named `tokens:/options:/parts:` shorthands and keep only `layout:` as a named swap. Everything else goes through positional patches.
5. Later (0.5.x), `it.default`-style re-parameterisation can be offered as `inner.with(..)` inside wraps, with no new signature.

### Drop

- locale-symmetry's `<style>-<layout>` preset matrix. Ship `themes.din-5008`, `themes.modern`, `themes.blank` plus `.with(layout: layouts.x)`.
- locale-symmetry's layout-as-function-of-style.
- tokens-first's arrangement enums (`letterhead.arrangement`, `bank.layout`, `geometry.references`). These become layouts and regions.
- tokens-first's `..named` DSL helpers and the Typst-side alias strings.
- user-first's 29 flat knobs, the `it =>` signature, `kinds` (defer until document kinds exist) and the singular `theme` namespace.
- structure-first's `frame view.totals = ctx.global`. Replace it with an explicit `(net, gross, due, prepaid)` record built by root.

### Conflicts and how I would decide them

| Conflict                                                                                         | Decision                                                                                                                                                                                                                                                                                                                                                                          |
| ------------------------------------------------------------------------------------------------ | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Region-inferred layout** (tokens-first, user-first: yes; structure-first, locale-symmetry: no) | **No inference in 0.5.0.** The default is `layouts.din-5008-a`. Swiss, French and UK millimetre values are unverified against postal masks, and silently defaulting a ch/fr user onto them is a compliance risk that becomes a visual break when corrected. Ship a documented table, plus `layouts.for-region(region)` later as an additive helper.                               |
| **Called vs uncalled preset**                                                                    | Accept both (structure-first/user-first style: named `base: auto`), validate the evaluated dict, and document uncalled as canonical.                                                                                                                                                                                                                                              |
| **Part signature**                                                                               | `(ctx, view) => content`; wrap `(ctx, view, inner) => content`. The house ctx-first convention wins over `it =>` and over `super:` named args. Wrappers compose across layers (structure-first, verified).                                                                                                                                                                        |
| **Rich vs thin tokens**                                                                          | Middle: a frozen semantic tier of about 40 leaves with seed derivation, and per-part options provisional with rename aliases. Grow tokens additively after 0.5.0; never shrink.                                                                                                                                                                                                   |
| **Layout engine scope**                                                                          | Freeze the region _schema_, but mark `arrange: function`, `float`, `isolate` and `reserve` **experimental**, along with the frame-part list beyond the DIN set. Add a **required-parts validation**: the resolved layout must host `recipient` and `sender`, and `notices` stays core. Reserved zones must also suppress marks and stationery and relocate, not drop, the footer. |
| **Legal footer on a reserved last page**                                                         | Unresolved in every proposal. Recommendation: the frame renders a `pages: "all"` footer region in flow above the reserved zone on that page. If that does not fit, panic with an explanation rather than drop it.                                                                                                                                                                 |
| **Minimum compiler**                                                                             | Stay on **0.14.0**. No proposal needs 0.15. The first milestone adds a 0.14.0 CI job that also checks the sealing cost and `to-absolute`/`here()` behaviour. Revisit `path()` only if the assets loader proves insufficient.                                                                                                                                                      |

### Roadmap for the synthesis

| Milestone | Scope                                                                                                                                                                                           | Ships as                                     |
| --------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------- |
| M0        | `utils/patch.typ` adopted by locale, `lang` fix, `set document` in root                                                                                                                         | 0.4.3                                        |
| M1        | Theme engine: merge, validate, seal, typed DSL, semantic tokens. The parts registry wraps today's 5 slots. The frame is a shim over the old DIN document, so there is no visual churn. 0.14 CI. | –                                            |
| M2        | Own frame plus `layouts.din-5008-a/b`, legal footer (#18), continuation header, localised page numbers. letter-pro is removed.                                                                  | The one visual-reference pass                |
| M3        | View v2 (money records, core notes/EPC in measure), notices outside the part, table renderer reading tokens                                                                                     | Removes the 50 parameters and the crash bugs |
| M4        | Additional layouts as data, each with one reference test. Swiss, French and UK are flagged experimental until verified.                                                                         | –                                            |
| M5        | `themed`, `from-data`, contrast strict, PDF/A guards, docs trio, lock                                                                                                                           | 0.5.0                                        |
| 0.5.x     | QR-bill component in an experimental reserved region                                                                                                                                            | –                                            |

### loom nice-to-haves (not required)

1. An official opaque ctx slot, which would make sealing robust.
2. A deep `apply`/merge scope motif.
3. Export `matcher.display` plus an `optional()` matcher.
4. Fix the labelled-container crash.
5. A version-independent motif key for third-party furniture.
6. Fix the `observer` typo.
