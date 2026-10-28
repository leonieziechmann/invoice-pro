# Verdict: API design quality and consistency with the package philosophy

Judge lens: API consistency. I read all four proposals in full, the digest, `api-philosophy.md`, `component-contract.md` and `loom-capabilities.md` in full, and the relevant sections of the other four reports. I also ran my own probes against the prototypes in `scratchpad/proto-judge-api-consistency/{sf,uf}/tests/judge.typ`, compiled with typst 0.15.1.

## 0. Weights

| Criterion                           | Weight | Why                                                                     |
| ----------------------------------- | ------ | ----------------------------------------------------------------------- |
| consistency_with_package_philosophy | 20     | the core of my lens                                                     |
| third_party_ecosystem               | 15     | stress test (a), R40                                                    |
| customization_ladder_no_cliffs      | 12     | stress test (b), plus how precedence and merging behave                 |
| testability_docs                    | 12     | Key/Type/Description tables, a test per snippet, coverage against drift |
| stability_freezability              | 10     | v0.5.0 locks the API                                                    |
| simple_case_ergonomics              | 8      |                                                                         |
| any_format_flexibility              | 8      | maintainer decision 2 (other judges weight it higher)                   |
| compliance_safety                   | 5      |                                                                         |
| feasibility_typst_loom              | 5      |                                                                         |
| maintainer_effort                   | 5      |                                                                         |

`total` = sum(score × weight) / 100.

## 1. What "consistent with the house" means (the yardstick)

This is taken from api-philosophy.md P1-P19 and I-1..I-17.

1. A theme is a **lazy function, passed uncalled** and customized only with `.with(...)`. The running version injects the base schema, which is where forward compatibility comes from (P2, P3, custom.md:14).
2. Customization means **master schema plus strict cascading patches**. Unknown keys panic with a path. `auto` means untouched and `none` means off (P4, P5, P11).
3. The patch DSL is `<ns>.custom.*`. There is one **named-argument** helper per schema group, the helper name equals the group name, and every helper returns a **one-element array** so the block form composes (P6, P7). The locale version has bugs I-1 (the `return` loses patches), I-2 (the panic itself crashes), I-3 (silent ignores, depth-2 merge) and I-6 (helper drift). These must not be copied.
4. Presets are bare names. A public `build-*` factory is tier 2 for packages (P8, P9).
5. Values use ctx-first `(ctx, view) => content` signatures (P12). Errors look like `types.require` messages with `scope::param` paths (P15). Names are kebab-case, and a namespace is named after its parameter (P1, P14, I-14).
6. Every doc snippet has a test (P16, I-8).

**The most important thing my probes established:** three of the four proposals reintroduce locale's I-3 in a new form. Either Typst's `.with` silently replaces a dict-valued _named_ argument, or unknown named arguments are silently ignored, or named and positional layers are applied in a fixed order that ignores call order. Only locale-symmetry rejects named arguments outright.

## 2. Per-proposal critique

### 2.1 tokens-first

**What is right.** The presets have the locale shape, with **named** injection: `(..patches, base: none, env: none) => theme`. Calling a preset directly gives an educational panic (§2.1, verified in `build.typ`). The DSL returns one-element arrays and `verify/wrap.typ` proves that two `table(..)` calls in one block both apply, so I-1 is fixed. The strict merge prints the path and the allowed keys: ``unknown token `table.header-fil`. Allowed keys in `table`: ...``. Sides fold. `restyle(..patches)` takes exactly the document-level patch forms, and also accepts named dotted keys. That passes (b). Three details worth keeping: `resolve-theme` for third-party CI, rename aliases for provisional tokens (_"the old path simply becomes `"{new.path}"`"_), and a CI rule that built-in presets produce zero contrast lints.

**What is wrong, seen through my lens.**

- **Unknown named arguments are silently dropped.** `build-theme` calls `build(name, base, env, preset-patches + user.pos())` and never inspects `user.named()`. `themes.classic.with(form: "B")` or `themes.classic.with(color: red)` compiles and does nothing. That repeats I-3 at the one place a locale-savvy or old-API user will guess wrong first.
- **The DSL helpers drop the house helper style.** `#let _group(name) = (..keys) => (((name): keys.named()),)` has no named parameters, no `auto` defaults, no per-parameter `///` docs and no native `unexpected argument` error. Every typo surfaces only when `invoice()` runs. Helper names also differ from group names: `palette` writes `color` and `typography` writes `size`. That breaks P6 ("helper name == group name"), and the docs will have to explain it.
- **`theme:` accepts a dict, meaning "a patch onto classic"** (§2.1). For locale, `resolve-locale` accepts a dict meaning an _evaluated_ locale. The same kind of argument gets opposite meanings in sibling APIs (I-4 family).
- **Two new stringly concepts**: alias strings `"{color.primary}"` and `"$op"` descriptor dicts. The proposal admits _"Stringly-typed aliases ... no IDE help"_. A same-hand design would express derivations as functions (P12), as locale already does for `format.*`.
- **The ecosystem story contradicts itself.** §2.2 presents `build-theme` as tier 2, _"Builds a publishable theme (mirrors `locale.build-locale`)"_. §6.2 recommends that packages _"need no import of invoice-pro at all"_. If a package does call its own copy of `build-theme`, `validate` uses `leaf-types`/`templates`/`region-defaults` imported from **that** version, and the engine resolves `$op` descriptors with **that** version's resolver. The injected base therefore does not deliver forward compatibility for descriptors that a newer version adds.
- **Sealing breaks the no-import promise.** Parts reach tokens only through `themes.tokens-of(ctx)`, and _"the `sealed` layout is internal"_. A zero-import package part that needs a colour must either import invoice-pro or read `ctx.theme.sealed.value.tokens`, which is internal. The nordic example only works because its wrap never reads a token.
- **The page geometry depends on the locale region by default** (`geometry.profile: "regional"`). Switching `locale.de-de` to `locale.de-ch` silently moves the window. That is a hidden coupling between locale and theme that the house has never had (business-req tension 7).
- A 190-leaf token surface plus dependence on undocumented lazy hashing (_"observed behaviour, not a documented guarantee"_) is hard to freeze.

**Stress test.** (a) This mostly passes. A plain-dict package gets the running base, and component-tier renames are aliased for one minor version. It fails for parts that read tokens (sealed accessor) and for packages that call their own `build-theme`. (b) This passes. `restyle(p)` and `.with(p)` take the same patches. Geometry patches inside `restyle` are silently ignored rather than rejected.

### 2.2 structure-first

**What is right.** This is the best any-format model: named regions with `place`, `pages`, `x|right`, `y|bottom`, `brand`, `isolate` and `float`. Twelve formats were compiled from one body, including an A5 sidebar receipt delivered as a package with no invoice-pro import. Wrap markers compose across layers: _"Each wrapper receives the previous composition as `inner`"_. The parts registry is open, and custom regions may name custom parts. The typed token helpers (`colors(primary: auto, ...)`) give native `unexpected argument` errors. Parts read `ctx.theme.tokens.*`, which is public, so zero-import parts work (verified with `@local/acme-theme`). `themed` explicitly rejects layout patches with a clear message. `notices` is split out as its own compliance part. Validation messages use `theme::layout::regions::info` paths.

**What is wrong, seen through my lens. All four points below are verified by my probe, `sf/tests/judge.typ`:**

```
{"t1":"din-5008-a","t2primary":"rgb(\"#1f2937\")","t2size":"12pt","t3width":"50%","t4":["none","none"]}
```

1. **`themes.din-5008.with(form: "B")` is silently ignored** (`t1`). `build` reads only `layout/tokens/options/parts` from `patches.named()` and drops every other named key (I-3).
2. **The named shorthands `tokens:/options:/parts:` bring back the `.with` wholesale replacement** (`t2`). `.with(tokens: (color: (primary: red))).with(tokens: (size: ..))` loses red. This is exactly the trap user-first documented as its reason to avoid dict-valued named arguments.
3. **Precedence inversion** (`t3`). `build` applies named shorthands _before_ positional patches whatever the call order, so `din.with(brand).with(options: (totals: (width: 30%)))` gives 50%: the brand wins over the user's later tweak. That contradicts the proposal's own §4.1, _"L3 positional patches, in call order"_, and the house rule "later wins" (P3).
4. **Compliance hole** (`t4`). `compliance-parts = ("notices", "totals", "bank-details")`, so `part("recipient", none)` and `part("items-table", none)` both validate, and a layout may simply not host `recipient`. An invoice without a recipient address or a line-items table passes validation.

There are also naming problems. The default preset is called `themes.din-5008`, yet `themes.din-5008.with(layout: layouts.us-letter-10)` (walkthrough 8) produces a "DIN 5008" theme on US Letter. That keeps DIN at the centre of the naming, which maintainer decision 2 rejects. A new top-level `layouts` (plural) namespace feeds a `layout:` parameter on the theme, not on `invoice`. That repeats the I-14 plural drift and breaks the rule that a namespace is named after its parameter. The DSL mixes typed helpers (`colors`) with stringly ones (`options("items-table", ..)`, `region(name, ..fields)`, `part(name, ..)`). `themed` reads `patches.pos()` only, so `themed(tokens: ..)` is silently dropped even though `.with(tokens: ..)` works. That is a small failure of (b).

**Stress test.** (a) This passes best: the layout dict, parts and a patch dict need no import, and the running base is injected. By design, built-in regions added later do not appear in a third-party layout, and the proposal says so. (b) This passes for positional fragments and fails for the named shorthands.

### 2.3 locale-symmetry

**What is right.** This is the proposal a locale user could guess. `build-theme(style, layout)` maps to `build-locale(lang, region)`. Presets `<style>-<layout>` map to `<lang>-<region>`. The `style:`/`layout:` pipelines map to `strings:`/`region:`. `themes.custom.*` helpers are named, typed, have **helper name == group name**, return one-element arrays through `emit`, and are guarded by a coverage test (_"calls every helper with every key of its schema group"_, which fixes I-6). Named arguments are **rejected** with an educational message: ``theme: unexpected named argument(s) `form`. Themes take no named options - use patches ...``. This is the only proposal that closes the I-3 hole at the entry point. Unknown pipelines and non-dict patches panic.

Two things set this proposal apart:

- **Master schema objects `(defaults, types, hydrate)` are injected**, so an older package's closure validates against the _newer_ types. This was found by prototyping and verified across a real 0.5.0 to 0.5.1 package pair (`palette.link` injected and derived).
- **One `utils/patch.typ` fixes locale's own I-1, I-2 and I-3.** It is shipped first (M0) as a locale bugfix. For the maintainer this is the strongest consistency move on the table, because it makes the two APIs identical in behaviour, not just similar in look.

`themed(..patches)` uses the same DSL, and layout patches are rejected with a message. Compliance is the strongest of the four: the core frame is not replaceable, and a notes renderer that returns nothing panics. The docs trio mirrors the locale pages.

**What is wrong.**

- **Positional base injection copies a latent locale footgun.** With `(..overrides, base-style, base-layout)`, `themes.classic-din-5008-a(p1, p2)` binds `p1` and `p2` as the _bases_ and then fails deep inside with a missing-key error. The proposal should take tokens-first's _named_ injection with a "pass it uncalled" panic, and fix locale the same way in the shared utility.
- **Preset explosion (4 × 9 = 36 names) and no layout swap.** If a third party ships `acme` (style plus layout), a consumer who wants acme's look on US Letter cannot do it by patch unless the package exports the raw style. `.with` stops being the one verb there.
- **The layout is a function of the final style** (`marks.paint: style.palette.rule`). It mirrors `region(lang)` faithfully, but it couples geometry to colour. It should stay allowed and not be the norm.
- **Derivations resolve in positional schema order**: _"a user patch that references a later key gets a function instead of a value and a type error"_. That is a confusing error in the one place users write functions.
- **The frame is not replaceable, and zones only exist on page 1.** The proposal says so: _"a two-column sidebar invoice with the address in the sidebar ... must be expressed with zones plus body.gap tricks"_. That falls short of decision 2.
- Small points. `themed` ignores named arguments (`args.pos()`). `theme-scope` is a second top-level ctx key. The package imports invoice-pro only to reach `themes.wrap`, although the marker is a plain tagged dict that could be documented and built without importing.

**Stress test.** (a) This passes, verified across versions for style, layout and wrap. The limit is the fixed frame model. (b) This passes best: same helpers, layout explicitly rejected in scope.

### 2.4 user-first

**What is right.** It has the best five-minute path: `theme.classic.with(logo: .., color: .., font: .., medium: "digital")`. It renames the namespace from `themes` to `theme`, which follows the house rule that a namespace is named after its parameter (P1, fixing I-14). The builder is idempotent when called by hand, so the called/uncalled footgun cannot happen. Unknown knobs get "did you mean" errors, and typos are also caught in data files. `medium` is a mode that wins over styling, a good finding from testing. `it.default(..overrides)` re-parameterizes the built-in renderer, which makes wrapping easier than in any other proposal. `kinds: (reminder: ..)` is the only concrete answer to R27 (document kinds). Parts receive `it.tokens`, so zero-import packages can read tokens.

**What is wrong, seen through my lens. Probe `uf/tests/judge.typ`:**

```
{"t1":"rgb(\"#0074d9\")","t2":"rgb(\"#2ecc40\")","t3":"auto"}
```

1. **Precedence inversion** (`t1`). `theme.classic.with(color: blue).with((color: red))` stays blue. Named knobs are always pushed last (`user.push(normalize(named, "arguments"))`), so a brand file applied _later_ loses to a company theme's earlier named knob.
2. **Dict knobs replace wholesale** (`t3`). `.with(table: (row-fill: green)).with(table: (header: "filled"))` loses the row fill. The proposal admits this: _"the one rule users must learn"_. A same-hand API does not ask users to learn a rule that its own merge engine was built to remove.
3. **Overlapping knobs conflict silently** (`t2`). `stripes: red` and `table: (row-fill: green)` both write `parts.table.row-fill`, and dictionary order picks the winner. The "one vocabulary" claim is really two vocabularies for the same thing: 29 knobs plus the model groups `brand/tokens/page/parts`, sometimes naming the same path.
4. **It drops the `custom` DSL** (_"a second vocabulary"_). That contradicts P6/P7 and the maintainer's own locale idiom, so a user who knows the locale API has to learn a different model.
5. **`it => content`** replaces the ctx-first `(ctx, view)` convention (P12) that every slot and sub-renderer uses today. The raw ctx becomes `it.ctx`, marked **unstable**.
6. **`restyle` reads `knobs.named()` only**, so positional patch dicts, the documented layering tool, are silently dropped inside a scope. `restyle(layout: ..)` / `restyle(medium: ..)` are accepted and have no effect. So (b) holds for words but not for forms.
7. `layout: "din-5008-b"` uses strings where locale uses preset values. `layout: auto` infers the layout from the region, which is hidden coupling.

**Stress test.** (a) This passes: a knob dict validated against the running base, with no import. (b) It passes partially: same words, but positional forms are ignored and layout is silently accepted.

## 3. Scores

| Criterion (weight)                       | tokens-first | structure-first | locale-symmetry | user-first |
| ---------------------------------------- | ------------ | --------------- | --------------- | ---------- |
| any_format_flexibility (8)               | 7            | 10              | 6               | 7          |
| simple_case_ergonomics (8)               | 7            | 7               | 7               | 9          |
| customization_ladder_no_cliffs (12)      | 8            | 7               | 7               | 6          |
| consistency_with_package_philosophy (20) | 6            | 6               | 9               | 4          |
| feasibility_typst_loom (5)               | 6            | 8               | 8               | 7          |
| compliance_safety (5)                    | 8            | 6               | 9               | 8          |
| stability_freezability (10)              | 6            | 6               | 7               | 6          |
| maintainer_effort (5)                    | 4            | 5               | 6               | 6          |
| third_party_ecosystem (15)               | 6            | 8               | 7               | 8          |
| testability_docs (12)                    | 7            | 7               | 9               | 7          |
| **weighted total**                       | **6.52**     | **6.99**        | **7.66**        | **6.49**   |

**Ranking: 1. locale-symmetry, 2. structure-first, 3. tokens-first, 4. user-first.**

## 4. Synthesis recommendation

**The backbone is locale-symmetry's API shell.** Most of structure-first's **page-master model** becomes the _content_ of the layout pipeline. The idea: the house calling convention and the house patch engine, with a layout schema that can express any format.

### Keep from locale-symmetry (the backbone)

1. `utils/patch.typ`, shared with locale and shipped first as the locale bugfix (M0). It provides `emit` (one-element arrays, no `return`), a strict deep merge with `::` paths and allowed keys, sides folding, re-hydration of `none` groups, and markers.
2. Two pipelines, `style:` and `layout:`. Typed `theme.custom.*` helpers with helper name == group name, all `auto`, and a coverage test that compares helper parameters with schema keys. Raw dicts remain the target for brand files.
3. Injected **schema objects** `(defaults, types, hydrate)`. Tier-1 users tweak with `.with(custom.*)`. Tier 2 is `build-theme(style, layout)`. The docs trio mirrors locale (`index`, `custom`, `base`), with base tables generated from `types`.
4. Named arguments are rejected with an educational message, **everywhere**: on presets and on `themed`.
5. `themed(..patches)[..]` uses exactly the same helpers, rejects layout patches with a message, and re-derives tokens from the unresolved source.
6. The compliance core: metadata, lang, XML, notes decided in measure with a panic on empty output, zero-tax filtering, and an EPC `view.qr` built by core.

### Graft from structure-first

7. **The layout schema = regions** (`place: fixed|before|after|header|footer|background|foreground`, `pages: first|rest|last|not-last|all`, `x|right`, `y|bottom`, `parts` in reading order, `arrange`, `brand`, `isolate`, `float`, `reserve`). It replaces locale-symmetry's fixed `head/window/info/references/furniture` groups. This removes the fixed-frame cliff (sidebar, band, QR-bill float) without making the frame itself a replaceable part.
8. An **open parts registry**, with `(ctx, view) => content`. Wrap markers compose across layers: preset, brand, user, scope. Settle one wrap signature, ctx-first: `theme.wrap((ctx, view, super) => ..)`. Document the marker as a plain tagged dict so zero-import packages can build it.
9. **A layout swap as a patch**: `custom.layout(theme.layouts.us-letter-10)` replaces regions and merges nothing else. This removes the preset explosion. Ship **style presets only** (`theme.classic`, `modern`, `minimal`, `plain`) on a documented default layout. Layouts are _values_ in `theme.layouts.*`, not strings. A theme package's look can then be moved onto any layout with `.with`.
10. Row-scope capture (`options.row` / `theme-scope`) keeps `themed` reaching group and item rows. Put it inside the single `theme` ctx key.

### Graft from tokens-first

11. **Named base injection**, `(..patches, base: none, env: none)`, with a "pass the preset UNCALLED" panic. Apply the same fix to locale in `patch.typ`. It supersedes the positional `(base-style, base-layout)`, which lets stray positionals bind as bases.
12. **Order-free lazy derivation with a cycle guard**, replacing positional schema-order derivation. Derivations stay Typst functions `t => value` (P12). Alias strings `"{palette.primary}"` are accepted **only inside `from-data`**, because TOML cannot hold functions.
13. **Rename aliases for provisional keys** (one minor version), `resolve-theme(theme, env:)` for package CI, `specimen`, the regex `from-data` parser, and a CI rule of zero contrast lints for built-in presets.
14. **Mandatory parts**: `recipient`/address, `items-table`, `totals`, `notices` and `bank-details` may not be `none`. In addition, a **layout validator rule** that `recipient` must be hosted by exactly one first-page region or in the flow. This closes structure-first's verified hole.

### Graft from user-first

15. The **singular `theme` namespace** (`theme: theme.classic`), matching `locale:`/`locale.`, since backwards compatibility is not required.
16. The `medium`-style "mode wins over styling" rule, as the semantics of `layout.stationery` (`generated | background | pre-printed`). A brand-furniture region stays hidden in pre-printed mode even when a part is overridden.
17. `kinds` (patches per document kind), reserved as an **experimental** style/layout mapping keyed by `env.kind`, so R27 has a place in the frozen shape.
18. "Did you mean" suggestions added to the strict merge messages. Hex-string colour coercion only inside `from-data`.
19. Parts can re-parameterize the default renderer: `super(ctx, view, ..option-overrides)`.

### Drop

- Every **named dict shorthand** on presets: structure-first's `tokens:/options:/parts:` and user-first's `table:` etc. They reintroduce `.with` wholesale replacement and fixed-order precedence, both verified in my probes.
- Silent acceptance of unknown named arguments (tokens-first, structure-first).
- `theme:` accepting a dict. Accept only a function, with a message pointing to `theme.classic.with(theme.custom.from-data(..))`. One convention.
- Layout inferred from the region by default (tokens-first, user-first). Offer an explicit `theme.layouts.for-region(region)` helper and a docs table.
- `"$op"` descriptors, sealed-metadata as a contract (it may remain an internal optimisation if M1 measurements require it, but never behind the part API), 36 `<style>-<layout>` names, and the `it =>` single-argument signature.

### Resolved conflicts

| Conflict                                 | Decision                                                                                                        | Reason                                                                                                    |
| ---------------------------------------- | --------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------- |
| `themed` vs `restyle` for the scope verb | `themed(..patches)[..]`                                                                                         | two proposals, reads as the adjective of `theme`; tokens-first's token reader becomes `theme.tokens(ctx)` |
| Part signature `(ctx, view)` vs `it`     | `(ctx, view)`; wrap `(ctx, view, super)`                                                                        | P12 ctx-first; `ctx.theme` is public so tokens are reachable without import                               |
| Theme = style × layout vs layout swap    | both: `build-theme(style, layout)` for authors, `custom.layout(..)` swap patch for users                        | keeps locale symmetry and avoids preset explosion                                                         |
| DSL vs knobs                             | DSL (`theme.custom.*`), plus a `brand(color:, accent:, font:, logo:)` macro for the five-minute path            | P6/P7; the macro gives user-first's ergonomics without named-argument traps                               |
| Layout depends on style                  | allowed (`function \| dictionary`), dictionaries are the norm, and region fields may hold lazy `t => ..` values | mirrors `region(lang)` without forcing coupling                                                           |
| Compiler                                 | stay on 0.14.0; add a CI job on 0.14.0 in M0                                                                    | no proposal needs 0.15 (`path()`, `dictionary.map` avoided)                                               |

### loom nice-to-haves (not required)

A deep-merge `apply`. An exported `matcher.display` plus an optional path-reporting `match`. `ensure` that tells `none` from missing. A version-independent motif key, so packages could emit `info.*`. The labelled-container fix. The `observer` typo fix.
