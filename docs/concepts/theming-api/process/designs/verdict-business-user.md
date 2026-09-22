# Verdict: business users and integrators

Judge lens: real business users and integrators. I scored the proposals against the 44 requirements (R1-R44) and the 8 personas in `research/business-requirements.md`. I also ran two stress tests against **each proposal's own prototype**, copied to `scratchpad/proto-judge-business-user/<proposal>/` and compiled with typst 0.15.1. Everything marked "compiled" below was actually rendered. The files are `tests/sa.typ`, `tests/sb.typ` and `tests/sdate.typ` (tokens-first: `verify/sa.typ`, `verify/sb.typ`), with the outputs in `out/`.

---

## 1. Headline findings

1. **All four proposals get the big decisions right.** Each one owns the page frame, drops letter-pro, moves PDF metadata, `text.lang` and ZUGFeRD into core, and adds a validated deep merge in which `auto` means untouched and `none` means off. Each lets one seed colour re-derive the palette, and each has its prototype pass PDF/A-3b and PDF/UA-1, including the successor of `blank`. What separates them is the **layout model**, the **mid-ladder ergonomics** and **how much must be frozen**.
2. **A compliance hole none of them closed, reproduced in two prototypes.** Every proposal protects legal _notes_ and the _EPC payload_. None protects the invoice's **identity fields**: invoice number, invoice date and the title/subject. § 14 (4) UStG makes number and date mandatory.
   - structure-first: `themes.modern.with(themes.custom.region("masthead", none))` compiles cleanly to an invoice **without number, date or title** (`structure-first/out/sdate.png`).
   - user-first: `layout: (.., info: none)` combined with modern's `info: (position: "block")` silently drops the date and all references (`user-first/out/sa-1.png`).
   - The synthesis must add an identity guard next to the notices guard (§6).
3. **The layout model decides whether "any format" is real.**
   - structure-first's regions can express everything tried, including an A5 sidebar, a QR-bill float zone and a band with the logo on the right, without writing a renderer.
   - locale-symmetry and user-first hard-code "page-1 zones (letterhead/window/info) + furniture". locale-symmetry says itself that "the core frame is not replaceable" and that a sidebar layout is "hard to express".
   - tokens-first sits in between: enums, then `parts.frame` as the escape.
   - Maintainer decision 2 ("ANY format ... DIN just one layout") favours regions.
4. **Region geometry has cliffs of its own.** In stress test (a) on structure-first, a full-bleed band placed as a `background` region does not reserve body space. The info block rendered _inside_ the blue band until I set `body-top: 40mm` by hand. No validator catches this.
5. **One stationery switch beats knob juggling for the DACH persona P2.**
   - structure-first and locale-symmetry switch pre-printed paper and the digital SVG letterhead with a single value.
   - tokens-first needs 2 tokens.
   - user-first needs 4 knobs. Its `footer: none` also kills the page number, and `stationery:` does not imply "don't draw the generated letterhead over the SVG".
6. **user-first has the best 80% case, but it breaks the house style.** It offers one-line flat knobs, `theme: toml(..)`, did-you-mean errors, hex-string coercion and an `assets:` loader. It also deletes the `ns.custom` patch-DSL idiom, renames `themes` to `theme`, and freezes a 29-parameter signature. That is the same "flat params" shape the research criticised in the 50-parameter renderer.

---

## 2. Weights (business lens)

| Criterion                           | Weight |
| ----------------------------------- | ------ |
| any_format_flexibility              | 1.5    |
| simple_case_ergonomics              | 1.5    |
| customization_ladder_no_cliffs      | 1.5    |
| compliance_safety                   | 1.5    |
| feasibility_typst_loom              | 1.0    |
| stability_freezability              | 1.0    |
| consistency_with_package_philosophy | 0.75   |
| maintainer_effort                   | 0.75   |
| third_party_ecosystem               | 0.75   |
| testability_docs                    | 0.75   |

Total = weighted mean (sum of weight × score / 11).

---

## 3. Requirement coverage (MUST = 19, SHOULD = 13; R44 excluded by maintainer decision 1)

Full = 1, partial = 0.5 (designed but not prototyped, or covered only by an override), 0 = deliberately absent.

|                                             | tokens-first                                                           | structure-first                                       | locale-symmetry               | user-first                                               |
| ------------------------------------------- | ---------------------------------------------------------------------- | ----------------------------------------------------- | ----------------------------- | -------------------------------------------------------- |
| R2 logo (placement incl. right, alt, size)  | 0.5: arrangement enum has no "right"; band = logo left                 | 1: any region/arrange                                 | 1: `logo.position` left/right | 0.5: letterhead style enum, no right                     |
| R4 font roles + tabular default             | 1                                                                      | 0.5: no tabular default                               | 1                             | 0.5: `numbers: "proportional"` in classic                |
| R15 legal footer from blocks + custom (#18) | 0.5: `auto` = fixed 4 columns _or_ a content array; no reusable blocks | 1: part names + content + functions in one region     | 1: `themes.footer.*` builders | 1: `theme.blocks.*`, reads `register/management/capital` |
| R18 regulated zones                         | 0.5: not prototyped                                                    | 1: float + isolate prototyped (placeholder slip)      | 0.5                           | 0.5                                                      |
| **MUST total**                              | **17.5**                                                               | **18.5**                                              | **18.5**                      | **17.5**                                                 |
| R5 contrast                                 | 1: derive + lints + strict                                             | 0.5                                                   | 0.5                           | 1: auto-fix / strict                                     |
| R6 brand from data                          | 1: `from-data` regex parser                                            | 0.5: user must call `rgb()`; `parse-length` not built | 0.5: 0.5.x                    | 1: spread + hex coercion + `assets` loader (verified)    |
| R11 layout from region                      | 1                                                                      | 0: deliberately left out                              | 0: deliberately left out      | 1                                                        |
| R19 header arrangements without a renderer  | 1 (enum)                                                               | 1 (regions)                                           | 0.5                           | 0.5                                                      |
| R23 table knobs                             | 1                                                                      | 0.5: 3 frozen options                                 | 1                             | 0.5                                                      |
| R27 document kinds                          | 0.5: `env.kind`                                                        | 0.5: `view.document.kind`                             | 0.5                           | 1: `kinds:` verified                                     |
| R32 guard rails                             | 0.5                                                                    | 0.5                                                   | 0.5                           | 0.5                                                      |
| R33 mono/ink-saving                         | 0.5                                                                    | 0.5                                                   | 0.5                           | 0.5                                                      |
| R42 single switch per output mode           | 1                                                                      | 1                                                     | 1                             | 0.5                                                      |
| others (R17, R25, R28, R41)                 | 4                                                                      | 4                                                     | 4                             | 4                                                        |
| **SHOULD total**                            | **11.5**                                                               | **9.0**                                               | **9.0**                       | **10.5**                                                 |

All MUSTs not listed (R1, R3, R8-R10, R12-R14, R16, R22, R24, R30, R31, R39, R40) score 1 for every proposal. No proposal fails a MUST outright. Coverage therefore does not decide the ranking; the stress tests and freezability do.

---

## 4. Stress tests (compiled)

### (a) US Letter "modern": full-width band, logo right, no window, 3-column legal footer on every page, page x/y

|                                      | Lines               | Renderer written?                                                                                                          | Where it broke                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 |
| ------------------------------------ | ------------------- | -------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **tokens-first** (`verify/sa.typ`)   | ~20                 | **Yes**: `part("letterhead", ..)`. `letterhead.arrangement: "band"` hard-codes logo left, sender right (`parts.typ:56-81`) | No `letter-digital` profile in the prototype (it is listed in the DSL doc), so I used `geometry(profile: "a4-digital", paper: "us-letter", ..)`. The footer had to be literal content: `footer.columns` is `auto` (4 generated columns) or an array of content, with no blocks to mix (#18 asks for exactly that). I read the logo through `t.assets.logo`, which is not a documented accessor. The table header-fill gap (E17) is visible. Result correct otherwise, including "Page 1 of 2". |
| **structure-first** (`tests/sa.typ`) | ~15, data only      | No: `band` + `band-title` (logo right) are shipped parts                                                                   | (1) The band is a `background` region, which does **not reserve** body space, so the info block rendered inside the band. Fixed with `layouts.modern + (paper: "us-letter", body-top: 40mm)`. (2) Removing `masthead` (which holds the logo, so it would otherwise appear twice) silently removed the **invoice date**. `info-block` does not carry it. Footer columns needed two small inline `(ctx, v) => ..` functions. Everything else is data and composes well.                          |
| **locale-symmetry** (`tests/sa.typ`) | **12**, tokens only | No: `logo(position: "right")`, `footer(blocks: ..)`, `furniture(footer: "all")`                                            | Removing the window needs the raw patch `(layout: (window: none))`, because the helper cannot express it. `a4-digital` keeps an A4 "window" rectangle in mm on Letter paper. The page number overlaps the top of the footer blocks. **The smoothest run**, but only because this exact combination was anticipated by tokens. A sidebar variant would hit the non-replaceable frame.                                                                                                           |
| **user-first** (`tests/sa.typ`)      | ~20                 | **Yes**: a full `letterhead: it => ..`, because band style is logo left and there is no position option                    | No `us-letter` digital layout ships, so I wrote an inline geometry dict, which works thanks to the deep merge. **`info: none` silently dropped date, customer no. and VAT id.** `theme.blocks.page-number` as a footer column works nicely.                                                                                                                                                                                                                                                    |

### (b) German GmbH on pre-printed letterhead (no generated header/footer, keep DIN window), switching to a digital SVG letterhead via `sys.inputs`

|                     | Knobs switched                                                                                                            | Result                                                                                                                                                                                                                                                                                |
| ------------------- | ------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **tokens-first**    | 2: `letterhead(mode: "pre-printed" \| "none")` plus an always-set `background(..)` (suppressed when pre-printed)          | Works. The mode name `"none"` (a string) next to the `none` value is confusing. **The stationery SVG is not stretched to the sheet** and lands offset inside the page (`out/sb-sheet.png`), so users must write `image(.., width: 100%, height: 100%)`.                               |
| **structure-first** | **1**: `stationery("pre-printed" \| (first:, rest:))`. `brand: true` regions drop automatically; geometry and window stay | Works. The continuation header (not `brand`) still prints over the SVG on page 2, so it needs `region("continuation", brand: true)` if the art has its own header. SVG not stretched either.                                                                                          |
| **locale-symmetry** | **1**: `stationery(mode: "pre-printed" \| "background", first:, rest:)`                                                   | Works, clean. SVG not stretched.                                                                                                                                                                                                                                                      |
| **user-first**      | **4**: `medium`, `stationery`, `letterhead: none`, `footer: none`                                                         | Works, but `stationery:` does not suppress the generated letterhead and footer, so the user must know to null them. `footer: none` also removed the page number from page 1. On the plus side, stationery _is_ stretched to the sheet, and "medium wins over styling" is a good rule. |

### Takeaways for the synthesis

- Logo placement (left, right, centre, in band) must be a **token/option**, not a reason to write a renderer. This was the cliff in two of the four proposals.
- Footer = **region/zone hosting an array of named blocks + content + functions**. structure-first's mechanism with user-first's block catalogue.
- Stationery = **one mode value** that implies what gets suppressed (brand-flagged furniture), with the art stretched to the sheet by default.
- Geometry needs **auto-reserve for every first-page region that overlaps the text area, including background bands**, plus a lint for overlap between fixed regions and the window.
- Identity fields need a **compliance guard** (§6).

---

## 5. Scores

| Criterion (weight)                         | tokens-first | structure-first | locale-symmetry | user-first |
| ------------------------------------------ | ------------ | --------------- | --------------- | ---------- |
| any_format_flexibility (1.5)               | 7            | **9**           | 6               | 6          |
| simple_case_ergonomics (1.5)               | 7            | 7               | 8               | **9**      |
| customization_ladder_no_cliffs (1.5)       | 7            | 6               | 7               | 7          |
| consistency_with_package_philosophy (0.75) | 7            | 7               | **9**           | 5          |
| feasibility_typst_loom (1.0)               | 6            | 8               | 8               | 8          |
| compliance_safety (1.5)                    | 8            | 8               | **9**           | 7          |
| stability_freezability (1.0)               | 7            | 6               | 6               | 6          |
| maintainer_effort (0.75)                   | 5            | 6               | 6               | 7          |
| third_party_ecosystem (0.75)               | **9**        | **9**           | 8               | 7          |
| testability_docs (0.75)                    | 7            | 7               | 8               | 7          |
| **weighted total**                         | **7.05**     | **7.36**        | **7.48**        | **7.02**   |

### Why these scores

**tokens-first**

- **Strong:**
  - The data story is the best: the brand is a data file, descriptors are pure data, and third-party packages need zero imports.
  - The contrast tooling is the most complete: `legible`, `on`, lints, strict mode and `specimen`.
  - `resolve-theme` makes token assertions unit-testable.
- **Weak:**
  - About 190 tokens, with aliases given as strings (`"{color.primary}"`) that get no IDE help. The authors admit this: _"About 190 tokens is a large learning surface"_.
  - Performance depends on an undocumented engine property: _"The sealing performance trick depends on Typst hashing content lazily ... without it the overhead is about 300 ms."_ That is a feasibility risk for batch users (P5).
  - Arrangements stop at enums (_"a new composition needs a part or frame override"_), and `parts.frame` reintroduces a whole-document escape hatch.
  - The `..named` DSL helpers give up autocomplete and the house-style per-parameter docs.

**structure-first**

- **Strong:**
  - The only model in which DIN really is "one layout among many": `layouts.din-5008-a` is 20 lines of region data, and the A5 sidebar receipt from a zero-import package was compiled.
  - The QR-bill float/isolate zone is prototyped.
  - `notices` is split out as a compliance part with a render-time emptiness check (_"an empty result while `required` is a panic at render time"_).
  - `view.qr` is built in measure.
  - Measured overhead is only about 7%.
- **Weak:**
  - The token/option layer is thin (_"options.items-table._ beyond zebra/header-fill/column-order"\* is experimental). Businesses live on rungs 1-2, and here they jump to region editing.
  - Stress (a) showed that region edits are where users lose legally required content and collide with background bands.
  - The frozen surface is wide: region schema, a whole frame view (_"Frame parts receive the whole frame view, which broadens the frozen surface"_) and about 25 part names.
  - `.with(layout:, tokens:, options:, parts:)` are dict-valued named arguments. user-first verified that `.with` replaces those wholesale, so `acme.with(tokens: a).with(tokens: b)` silently loses `a`. The proposal never mentions this.
  - Region inference (R11) is refused.

**locale-symmetry**

- **Strong:**
  - Truest to the house style: one shared `utils/patch.typ` fixes the three verified locale bugs, and locale can adopt it in M0 as a standalone fix.
  - Forward compatibility is _verified_ across two package versions (`palette.link` injected).
  - The richest style tokens for rungs 1-2.
  - The core frame guarantees the address stays in the window.
  - It won stress test (a) with tokens only.
- **Weak:**
  - The **preset name explosion** (_"about 4 x 9 = 36 names"_) would freeze dozens of public names in v0.5.0.
  - Positional derivation order (_"a derivation may only reference keys defined earlier in schema order"_) is a trap for brand authors.
  - Each key is written three times (defaults, types, helper).
  - The ceiling is structural: _"Layouts that are not 'absolute zones on page 1 plus furniture' (for example a sidebar-address design) are hard to express."_ This contradicts maintainer decision 2.
  - Removing a window needs a raw patch.
  - It rejects called and dict themes, so `theme: toml(..)` does not work directly.

**user-first**

- **Strong:**
  - The best rung-0/1 experience: P1 is one line.
  - `theme: toml(..)` works, with did-you-mean errors (verified), a `kinds:` document family, an `assets:` loader across the package boundary (verified), stationery stretched to the sheet, and the "medium wins over styling" rule (found by testing).
  - The idempotent called form removes the old footgun.
  - The smallest frame (84 lines).
- **Weak:**
  - It rejects the `ns.custom` DSL (_"A `themes.custom._`helper DSL like`locale.custom`: a second vocabulary"\*), where the house style would be to fix that DSL.
  - 29 frozen knobs, plus a knob-to-path sugar mapping that must stay stable forever.
  - The `it =>` single-argument parts break the ctx-first convention (api-philosophy P12).
  - `it.ctx` is exposed as an unstable escape hatch.
  - Dict knobs still carry the `.with` wholesale trap (the authors admit this).
  - Legal notes and the EPC payload are _"still inside renderers in the prototype"_.
  - Stress (b) needed 4 knobs.
  - `layout` is an inline dict with fixed zone names, so no custom regions.

---

## 6. Ranking

1. **locale-symmetry** (7.48)
2. **structure-first** (7.36)
3. **tokens-first** (7.05)
4. **user-first** (7.02)

The top two are close, and they are good at _different layers_. The synthesis should take the API shell from one and the layout engine from the other.

---

## 7. Synthesis recommendation

### Backbone (two layers)

- **Public API shell and merge engine: locale-symmetry.** Take `utils/patch.typ` shared with locale (strict deep merge, sides folding, `wrap` marker, re-hydration of `none` groups, one-element-array helpers without `return`, `::` path errors). Take `build-theme`, the `themes.custom` helper-per-group DSL, the `brand(..)` macro, injected master schema _objects_ `(defaults, types, hydrate)` for verified forward compatibility, and ship M0 as a locale bugfix.
- **Layout axis and part registry: structure-first.** Layouts are data made of named **regions** (`place`, `pages` selector, `x|right`, `y|bottom`, `parts` in reading order, `arrange`, `brand`, `isolate`, `float`, `reserve`). Parts are a flat registry `(ctx, view) => content`, with `wrap` composing across layers. `notices` is a separate compliance part. `themed` is an unnamed compute motif. This replaces locale-symmetry's fixed `head/window/info` zone schema. The DIN, SN, NF, UK and US presets become region dicts, and locale-symmetry's "layout = function of final style" stays available (a layout may be `(style) => dict`).

### Graft from the others

| From                      | Mechanism                                                                                                                                                                                                                                                                                                                                                                       | Why (business lens)                                                                                                                |
| ------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------- |
| tokens-first              | **Order-free lazy derivation with cycle guard**, not locale-symmetry's positional order. Descriptors (`tint`, `on`, `legible`, `mix`) as _plain dicts_, so brand files and zero-import packages can contain derivations. Plain `t => ..` functions stay the code form                                                                                                           | Brand authors never need to know schema order; P4/P5 data files can say "header text = on(primary)"                                |
| tokens-first              | `from-data` (regex length/colour parser, `"none"` → none, absence = inherit), `specimen`, contrast lints + `a11y: "strict"`, `resolve-theme` for unit tests, PDF/A guards (CMYK, PDF image `source`)                                                                                                                                                                            | R5, R6, R32, R43; CI personas                                                                                                      |
| tokens-first              | Semantic token tiers (color/font/size/weight/space/stroke, including `font.numeric`, `font.figures: "tabular"` and `font.regulated`), trimmed to about 60 frozen semantic tokens plus small per-part option groups. No `ref.*` tier in the frozen surface                                                                                                                       | Keeps rungs 1-2 rich without 190 frozen names                                                                                      |
| tokens-first / user-first | `layout: auto` = pick from locale region (de/at → DIN A, us → US Letter #10, fr → NF), with **ch mapped to DIN until SN coordinates are verified** (user-first's caution)                                                                                                                                                                                                       | R11 is a SHOULD. Explicit `layout:` always wins, which addresses structure-first and locale-symmetry's Swiss-left-window objection |
| user-first                | `theme:` accepts a dict/array (applied as a patch on the default theme) and the **idempotent called form** (structure-first also verified called = uncalled)                                                                                                                                                                                                                    | `theme: toml("brand.toml")`, `theme: json(sys.inputs.brand)` for P4/P5; the footgun disappears by construction                     |
| user-first                | Did-you-mean in unknown-key errors, hex-string colour coercion in data, the **`assets:` loader closure** for logo/stationery paths, `kinds:` per-document-kind patches, footer **block catalogue** (`sender`, `contact`, `register`, `tax-ids`, `bank`, `page-number`, `continuation`) reading new `sender.register/management/capital` keys, stationery stretched to the sheet | R6, R15, R27, R28 in practice                                                                                                      |
| user-first                | Rule: **an output mode wins over styling** (a user letterhead renderer must not re-show itself on pre-printed paper)                                                                                                                                                                                                                                                            | Found empirically; applies to the stationery switch below                                                                          |
| locale-symmetry           | Rich style groups for letterhead (fill band, `logo.position`, sender alignment), table, totals, bank and payment                                                                                                                                                                                                                                                                | Stress (a) showed that logo-right and band must be tokens, not renderers                                                           |
| locale-symmetry           | Core composes `table → totals → notes` and panics if `notes` renders nothing while notes exist; core-built `view.qr` closure clamped ≥ 20 mm, black on white                                                                                                                                                                                                                    | Compliance                                                                                                                         |

### New requirements the synthesis must add (from my stress tests)

1. **Identity guard.** Invoice number, invoice date, document title and the recipient address are _required outputs_.
   - Core computes `view.required.identity`.
   - At resolve time, validate that the active layout hosts at least one part that renders number and date (`title`, `info-block`, `masthead`, `band-title`, ...). Parts declare `provides: ("number", "date")`.
   - For custom parts, check at render time, the same way as notices. Otherwise core appends a fallback identity line.
   - Error example: `theme::layout: no region renders the invoice date (required by § 14 UStG / EN 16931 BT-2); add "info-block" or "title" to a region`.
2. **Auto-reserve and overlap lint.** `body-top: auto` must account for every first-page region that overlaps the text area, including `background` regions with a `height` (bands). Fixed regions that overlap the address window get a validation error.
3. **Stationery = one mode value**: `"generated" | "pre-printed" | (first:, rest:)`, with the art stretched to the sheet.
   - It suppresses `brand: true` regions (structure-first).
   - Page number and continuation stay unless flagged.
   - An output mode wins over part overrides (user-first).
4. **Footer region + block catalogue** as the #18 answer: `region("legal", place: "footer", pages: "all", arrange: (columns: (1fr, 1fr, auto)), parts: ("sender", "register", "page-number"))`, where parts accept block names, content (with `info.*` woven by core) and functions.

### Drop

- locale-symmetry's `<style>-<layout>` preset name explosion. Ship style presets (`classic`, `modern`, `minimal`, `plain`) and layouts (`layouts.*`) as two axes combined with `layout:`.
- locale-symmetry's positional derivation order and its triple key writing; generate the types from one schema instead.
- structure-first's dict-valued named `.with` shorthands `tokens:` / `options:` / `parts:`. They silently lose earlier values when chained. Keep only `layout:`, where wholesale swap is the intended semantics, and document that.
- user-first's 29-parameter flat builder, the `theme` rename, `it =>` single-argument parts and exported `it.ctx`. Also drop the `medium` + `stationery` + part-null juggling.
- tokens-first's ~190-token frozen surface with string aliases as the primary authoring form, `metadata` sealing _as a contract_ (keep it only as an internal optimisation, and ask loom for an official opaque value), `parts.frame`, and `from-dtcg` in 0.5.0 (0.5.x experimental).

### Conflicts and how I would decide them

| Conflict                                                                                                                                | Decision                                                                                                                                                                                                                                                            |
| --------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Part signature: `(ctx, view)` + `wrap(inner)` (structure-first / locale-symmetry) vs `super:` named (tokens-first) vs `it` (user-first) | `(ctx, view) => content`, with `wrap((ctx, view, inner) => ..)` composing across layers. It is ctx-first like every existing slot. Add a documented helper for "call the default with other options" (user-first's re-parameterise rung) instead of a new signature |
| Frame replaceable?                                                                                                                      | No (locale-symmetry). Regions provide the freedom, so `set document`, lang and window guarantees stay in core                                                                                                                                                       |
| Region inference (R11)                                                                                                                  | `layout: auto` = region default, explicit wins (see above)                                                                                                                                                                                                          |
| Called vs uncalled                                                                                                                      | Accept both, plus a dict. Validate the evaluated value (`kind` assertion)                                                                                                                                                                                           |
| Token count                                                                                                                             | About 60 frozen semantic tokens + per-part option groups marked stable/experimental (Docusaurus tiers from structure-first / tokens-first)                                                                                                                          |
| Views                                                                                                                                   | Adopt the common v2 contract all four specify: `(value, text)` records, plurals, notices/taxes/qr decided in measure, no `ctx.global` for parts. Freeze only the bold fields; the line-items view stays provisional until the table rewrite                         |
| Compiler                                                                                                                                | Stay on 0.14.0 (all four agree). Add a 0.14.0 CI job in M1 and verify `image.source`, `to-absolute` and PDF/A behaviour there. `path()` for brand files is the only reason to bump later                                                                            |
| loom nice-to-haves                                                                                                                      | Deep `apply`/scope-merge, exported `matcher.display` + `optional()` + path-reporting match, `ensure` distinguishing `none`, labelled-container crash fix, version-independent motif key, official opaque ctx value, `observer` typo                                 |

### Suggested milestone order (business value first)

1. **M0:** `patch.typ` + locale fix + `lang` fix + core `set document`, shippable as 0.4.3.
2. **M1:** engine + tokens + `classic` on region-DIN A/B + own frame (closes #18 with the block catalogue).
3. **M2:** stationery switch + identity guard + auto-reserve lint.
4. **M3:** view v2 + `notices` part + core QR.
5. **M4:** layouts US/UK/digital (SN/NF only after mask verification) + `layout: auto`.
6. **M5:** `modern`/`minimal`, `from-data`, `assets`, `kinds`, contrast strict, `specimen`, `themed`.
7. **M6:** docs trio + layouts page + packages page; lock.
