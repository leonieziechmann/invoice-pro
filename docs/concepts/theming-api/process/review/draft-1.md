# invoice-pro v0.5.0 Theming API: synthesized concept (draft 1)

Lead-architect synthesis of four proposals (structure-first, tokens-first, locale-symmetry,
user-first) and three verdicts (maintainer, business-user, api-consistency).
Prototype: `scratchpad/proto-synthesis/` (typst 0.15.1). Section 10 lists what was verified.

---

## Executive summary

**One sentence.** A theme is a lazy value like a locale: `theme.classic.with(..patches, layout: ..)`.
It combines a **page master written as data** (a layout made of named regions that host parts),
a **flat registry of part renderers** `(ctx, view) => content` that you can wrap or replace, and a
**small frozen token tier** (35 semantic tokens, derived from one seed colour) plus per-part
options. All of it is folded by **one strict patch engine**, shared with `locale`. Compliance
output lives in core.

**Backbone: structure-first.** All three judges picked its layout model, even the two who
ranked locale-symmetry first. Page masters are data made of regions. Each region has geometry,
a page selector and a list of hosted parts in reading order. invoice-pro owns the frame and
letter-pro is dropped. This is the only model in which DIN 5008 is really just one layout among
many. It covers DIN A/B, SN 010130 with a QR-bill zone, US Letter #10, digital A4, pre-printed
stationery and a third-party A5 sidebar receipt without anyone writing a renderer.

**Shell: locale-symmetry's conventions**, grafted as a whole:

- one shared `utils/patch.typ`, shipped first as a locale bugfix;
- typed `custom.*` helpers whose name equals the group name, each returning a one-element array;
- a coverage test;
- the master schema injected by `invoice()`, never imported;
- named arguments rejected with an educational message.

**Grafts:**

- **tokens-first:** the strict merge at every depth, templates for `none` groups, the replace
  marker, sealing the theme in ctx (internal only), order-free derivation, the legal notes
  appended outside the replaceable part, the EPC-QR built by core, `resolve-theme`, `from-data`
  with a regex parser, the contrast and PDF/A guards, rename aliases for provisional keys.
- **user-first:** the idempotent called form, did-you-mean hints, the `assets:` loader,
  "a mode wins over styling", stationery stretched to the sheet.
- **business judge:** the identity guard and the body-top/overlap fixes.
- **maintainer judge:** reserved zones that relocate the footer instead of dropping it, and the
  QR-bill as a frame part.

**Three decisions resolve the conflicts:**

1. **The layout is always the bottom layer.** A layout swap (`layout:`) replaces only the page
   master. Every patch, from look to brand to user tweak, is re-applied on top of it. Looks
   patch only the _standard region names_, never geometry. So any look works on any layout: the
   CI matrix test compiled 4 looks × 7 layouts, 28 of 28. This removes both the 36-name preset
   matrix and layouts that are functions of the style.
2. **Only one named argument exists: `layout:`.** Its semantics is "swap", which is exactly
   what Typst's wholesale `.with` replacement does. Every other named argument panics. That
   kills the verified `.with` traps (lost dicts, precedence inversion, silently ignored `form:`).
3. **Derivations are plain Typst functions `t => value`**, resolved by fixpoint. They are
   order-free and cycles are detected. There are no alias strings or `$op` descriptors in Typst
   code. Alias strings exist only inside data files, where `from-data` converts them into
   functions.

**Cut:**

- the 190-token surface and the `ref.*` tier;
- the arrangement enums (they are regions now);
- the 29 flat knobs and the `it =>` signature;
- `<style>-<layout>` preset names;
- dotted keys, `kinds:`, `from-dtcg` and a replaceable frame part in 0.5.0;
- region inference from the locale (moved to 0.5.x, see the appendix).

**Compiler:** stay on **0.14.0**. Nothing requires 0.15. A 0.14.0 CI job goes in at M0 and
includes the sealing benchmark.

**Measured (150 items, typst 0.15.1, 5 runs):**

| Variant                                        | Time                                                                                |
| ---------------------------------------------- | ----------------------------------------------------------------------------------- |
| 0.4.2 baseline (letter-pro, no running footer) | 1129–1156 ms                                                                        |
| Synthesis, theme sealed in ctx                 | 1226–1364 ms (+8 %, including the every-page footer, continuation header and marks) |
| Same, theme as a plain dict                    | 1894–1922 ms (+67 %)                                                                |

Sealing is therefore not optional as an implementation technique. It stays out of the
contract.

---

## Design decisions at a glance

| Decision                       | Choice                                                                                                                                                | Why                                                                                          | Source proposal                                    |
| ------------------------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------- | -------------------------------------------------- |
| Central model                  | layout (regions → parts) × parts registry × tokens/options                                                                                            | only model where any format is data; all three judges                                        | structure-first                                    |
| Calling convention             | lazy, passed uncalled; the called form is idempotent (`theme.classic(p)` == `theme.classic.with(p)`)                                                  | locale symmetry; the blank/DIN-5008 footgun disappears by construction                       | locale-symmetry + user-first                       |
| What `invoice(theme:)` accepts | functions only; a dict panics and the message points to `from-data`                                                                                   | one convention; a dict must not mean "patch" in one API and "evaluated" in another           | api-consistency judge                              |
| Named arguments on a theme     | only `layout:`; anything else panics with a hint                                                                                                      | `.with` replaces named dicts wholesale (verified), so only a swap-semantics argument is safe | user-first finding, api judge                      |
| Layout swap vs look            | layout = bottom layer; looks patch standard region names only                                                                                         | any look on any layout without a preset matrix                                               | new (synthesis)                                    |
| Presets                        | `theme.classic`, `modern`, `minimal`, `plain`; layouts in `theme.layout.*`                                                                            | two axes, no name explosion; DIN leaves the preset names                                     | business + api judges                              |
| Namespace                      | singular `theme` (`theme: theme.classic`), `theme.layout`, `theme.custom`                                                                             | the house rule "namespace == parameter"; the break costs nothing extra now                   | user-first, api judge                              |
| Patch DSL                      | typed helper per group, `auto` = untouched, one-element arrays, coverage test                                                                         | P6/P7 house idiom, IDE completion, native `unexpected argument`                              | locale-symmetry                                    |
| Merge engine                   | strict at every depth with `::` path, did-you-mean and allowed keys; sides fold; templates; wrap/replace markers; arrays replace                      | best of three engines; fixes locale I-1/I-2/I-3                                              | tokens-first + locale-symmetry + user-first        |
| Shared utility                 | `utils/patch.typ` used by theme and locale, shipped first (0.4.3)                                                                                     | value before the API lock; proves the semantics                                              | locale-symmetry                                    |
| Schema definition              | written once with `field(default, ..types)`; defaults and types derived mechanically                                                                  | no triple writing (only helpers repeat keys, guarded by a test)                              | new (fixes locale-symmetry weakness)               |
| Base injection                 | a schema object injected as named `base:` plus `env:`, never imported                                                                                 | forward compatibility; stray positionals cannot bind as bases                                | locale-symmetry + tokens-first                     |
| Tokens                         | 35 frozen semantic leaves in 6 groups, derived from `colors.primary`                                                                                  | R3 without a 190-name freeze                                                                 | tokens-first (trimmed)                             |
| Default look via derivation    | `surface = OKLCH(92.88 %, 0.4264·C, h)` of the seed gives exactly `#e2e8f0` for the default seed                                                      | brand colour re-derives the zebra, and the default look is preserved                         | new (verified)                                     |
| Derivations                    | `t => value` functions, fixpoint resolution (≤ 6 rounds), cycle panic                                                                                 | order-free; no stringly aliases; functions are house style (P12)                             | tokens-first semantics, locale-symmetry syntax     |
| Options                        | per-part, provisional, with rename aliases for one minor version                                                                                      | the component tier can grow and change without breaking                                      | structure-first + tokens-first                     |
| Part signature                 | `(ctx, view) => content`; wrap `(ctx, view, inner)`; `theme.adjust(ctx, ..patches)` to re-parameterise `inner`                                        | ctx-first (P12); wrap composes across layers; the middle rung of the ladder                  | structure-first + user-first idea                  |
| Wrap marker                    | a documented plain tagged dict                                                                                                                        | zero-import packages can wrap                                                                | api judge                                          |
| Scoped overrides               | `themed(..patches)[..]`: same patches; layout and named args rejected                                                                                 | one vocabulary for document and subtree                                                      | structure-first / locale-symmetry                  |
| Page frame                     | owned by core, not replaceable; regions give the freedom                                                                                              | 0.4 lost metadata and window guarantees through a replaceable document slot                  | locale-symmetry principle + structure-first engine |
| Legal notes                    | the component calls `notices` outside the replaceable `line-items` part; `none` refused; empty output while required panics                           | cheapest guarantee plus a guard                                                              | tokens-first + structure-first                     |
| Identity guard                 | layout must host `recipient` (exactly once) and `title` in a first-page or flow region; empty output panics                                           | § 14 UStG number and date; verified hole in two prototypes                                   | business judge                                     |
| EPC-QR                         | payload built in `bank-details` measure as `view.qr(size)`: black on white, ≥ 20 mm                                                                   | a part can place it, never break it                                                          | tokens-first / locale-symmetry                     |
| Stationery                     | one layout value: `"generated"`, `"pre-printed"` or `(first:, rest:)`; drops `brand: true` regions regardless of renderer; art stretched to the sheet | one switch per output channel (R42); mode wins over styling                                  | structure-first + user-first                       |
| Reserved zones                 | a floated `after` region at the bottom edge, white-filled (covers marks and stationery); page footers relocate into the flow above it                 | maintainer MUST-ADD; footers are legal content                                               | maintainer judge (built in prototype)              |
| body-top                       | auto-reserves first-page fixed regions and first-page background bands with a height                                                                  | business stress test (a)                                                                     | business judge                                     |
| Region safety                  | overlap lint against the address window; flow regions reject `pages`; a new region needs `place`                                                      | typos and misplacement become errors                                                         | new                                                |
| Region inference               | none in 0.5.0; documented table; `theme.layout.for-region` in 0.5.x after mask verification                                                           | silent defaulting to unverified CH/FR millimetres is a compliance risk                       | maintainer + api judges                            |
| Brand files                    | `theme.custom.from-data(dict, assets:)`: regex parser, hex, `"{colors.primary}"` aliases, `none`                                                      | R6 without `eval`; aliases only where functions are impossible                               | tokens-first + user-first                          |
| Sealing                        | internal `metadata` wrapper in ctx; parts get an unsealed ctx                                                                                         | +8 % instead of +67 % at 150 items (measured)                                                | tokens-first (made invisible)                      |
| Validation                     | resolve-time strict checks; contrast (opt-in `checks.min-contrast`); PDF/A guards when `zugferd` is set; logo alt text                                | R5, R31, R32                                                                                 | tokens-first + structure-first                     |
| Minimum compiler               | stay 0.14.0; M0 CI job                                                                                                                                | nothing needs 0.15                                                                           | all                                                |
| Dropped for 0.5.0              | `ref.*` tier, enums, descriptors, dotted keys, knobs, `it =>`, `kinds:`, `parts.frame`, DTCG, preset matrix                                           | freeze budget of a solo maintainer                                                           | –                                                  |

---

## 1. Pitch & mental model

Every invoicing product separates the page master (paper, window, letterhead, footer zones)
from brand (logo, colours, fonts) and content style (table, totals). invoice-pro 0.4 fuses all
three into `themes.DIN-5008(...)` and delegates geometry to a third-party package. v0.5.0
separates them. The rule, taken from locale-symmetry's docs framing:

> **Data decides _what_, core decides _where_, the theme decides _how_.**

```
                       theme.classic.with(brand, tweaks, layout: theme.layout.us-letter-10)
                                         │  lazy: nothing happens until invoice() calls it
                                         ▼
 invoice() ─ injects ─► base: schema object of the RUNNING version      env: (kind, lang, region, zugferd)
                                         │
      ┌──────────────── fold (one strict engine, utils/patch.typ) ────────────────┐
      │ L0 schema defaults (tokens, options, parts, checks)                       │
      │ L1 LAYOUT (page master)   ← `layout:` swaps only this layer               │
      │ L2 look patches (preset)  ← patch standard region NAMES, never geometry   │
      │ L3 positional patches in call order (brand, company, document tweaks)     │
      └──────────────────────────────────┬────────────────────────────────────────┘
                   resolve (derivations t => v, fixpoint) → validate → seal
                                         ▼
                     ctx.theme  (ONE key, opaque to loom, unsealed for parts)
            ┌────────────────────────────┼─────────────────────────────┐
            ▼                            ▼                             ▼
   CORE (not themable)             FRAME (core)                  COMPONENTS (body)
   set document, text.lang,        set page; regions from        line-items, bank-details,
   factur-x.xml, legal notes       layout → call PARTS           payment-goal, signature
   decision, EPC payload,          (frame view, fresh)           → call PARTS (body views)
   required-part checks
            L4  themed(..patches)[subtree]   (tokens/options/parts; re-derives)
            L5  explicit component args      (per instance; data > presentation)
```

Five concepts, each with one job:

| Concept    | Is                                                                                                | Frozen in 0.5.0                         |
| ---------- | ------------------------------------------------------------------------------------------------- | --------------------------------------- |
| **Layout** | data: paper, margin, marks, stationery, named **regions** (geometry, page selector, hosted parts) | layout and region schema                |
| **Part**   | a renderer `(ctx, view) => content` with a documented view; wrap or replace                       | part names, signature, bold view fields |
| **Token**  | 35 semantic design decisions derived from 1–2 seeds                                               | all 35 paths                            |
| **Option** | a knob of one built-in part (`items-table.zebra`)                                                 | provisional (rename aliases)            |
| **Patch**  | a dict in patch shape, usually produced by a `theme.custom.*` helper                              | helper names, merge rules               |

The customization ladder has no cliff between rungs:

1. `theme.classic` (a preset).
2. `.with(theme.custom.brand(color:, logo:))`.
3. `.with(layout: theme.layout.din-5008-b)` plus `marks(none)`, `stationery(..)`.
4. `region("letterhead", parts: ("sender", "logo"))` (logo right, as data).
5. `wrap("totals", ..)` or `part("payment-goal", ..)`.
6. Your own layout dict with custom regions and parts.

---

## 2. Public API surface

### 2.1 Exports (`#import "@preview/invoice-pro:0.5.0": *`)

| Export               | Kind                                      | Content                                                                                                                                                                                                          |
| -------------------- | ----------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `invoice(theme: ..)` | changed param                             | `function`, default `theme.classic`                                                                                                                                                                              |
| `theme`              | module (replaces `themes`)                | presets `classic`, `modern`, `minimal`, `plain`; `layout` (submodule); `custom` (patch DSL, submodule); `build-theme`; `resolve-theme`; `adjust`; `parts` (default renderers); `contrast`, `on-color`, `legible` |
| `theme.layout`       | submodule of plain dicts                  | `din-5008-a`, `din-5008-b`, `us-letter-10`, `a4-digital`, `letter-digital`, `plain`; experimental: `sn-010130-right`, `sn-010130-left`, `nf-z-11-001`, `uk-c5`; `derive(base, ..patches)`                        |
| `themed`             | bare function (a body verb, like `apply`) | subtree override                                                                                                                                                                                                 |

Namespace rule: _values passed to a parameter live in a namespace named after it_
(`locale:`/`locale.`, `theme:`/`theme.`). Sub-namespaces mirror locale: `theme.layout` ≈
`locale.region`, `theme.custom` ≈ `locale.custom`, `theme.build-theme` ≈ `locale.build-locale`.

### 2.2 The lazy theme

```typst
/// A lazy theme (preset or `build-theme` result). Pass it UNCALLED; customise it with
/// `.with(..patches, layout: ..)`. Calling it without an injected base is identical
/// to `.with` (idempotent), so `theme.classic` and `theme.classic()` are both valid.
///
/// -> dictionary
(
  /// Patch fragments, applied in call order ON TOP of the layout.
  /// -> dictionary | array
  ..patches,
  /// Swaps the page master (the bottom layer). Chained `.with(layout: ..)`: last wins.
  /// -> auto | dictionary
  layout: auto,
  /// Injected by `invoice()`: the running version's schema object. Never set by users.
  /// -> none | dictionary
  base: none,
  /// Injected by `invoice()`: (kind, lang, region, zugferd).
  /// -> none | dictionary
  env: none,
) => dictionary
```

Any other named argument panics. Verified message:
``theme `classic`: unexpected named argument(s) `form`. A theme takes patches (e.g. `.with(theme.custom.colors(primary: teal))`) and `layout:` (e.g. `layout: theme.layout.din-5008-b`).``

### 2.3 Presets

```typst
/// Today's look on DIN 5008 form A. Default of `invoice`.
#let classic = build-theme(name: "classic", layout: layout.din-5008-a, looks.classic)
/// Brand band, stacked title in primary, filled table header, tinted totals. Digital A4.
#let modern  = build-theme(name: "modern",  layout: layout.a4-digital, looks.modern)
/// Hairlines, no fills, large white space ("Stripe-like"). Digital A4.
#let minimal = build-theme(name: "minimal", layout: layout.a4-digital, looks.minimal)
/// Successor of `blank`: no furniture; title and recipient in the flow.
#let plain   = build-theme(name: "plain",   layout: layout.plain,      looks.classic)
```

`modern` on DIN paper is `theme.modern.with(layout: theme.layout.din-5008-b)`. The band look
survives the swap because looks only patch region _names_ (verified by an assertion in
`tests/coverage.typ` and visually in `out/m-modern-din-5008-a-1.png`).

### 2.4 Tier 2: `build-theme`, `resolve-theme`, `adjust`

```typst
/// Builds a lazy theme (company themes, Typst Universe packages).
/// -> function
#let build-theme(
  /// Name shown in error messages. -> str
  name: "custom",
  /// Default page master. -> dictionary
  layout: none,
  /// Look patches, applied before user patches. -> dictionary | array
  ..look,
)

/// Evaluates a lazy theme outside an invoice (unit tests, third-party CI).
/// -> dictionary
#let resolve-theme(theme, env: (kind: "invoice", lang: "de", region: "de", zugferd: none))

/// Inside a wrapper: a ctx whose theme carries extra patches, to re-parameterise `inner`.
/// `inner(theme.adjust(ctx, theme.custom.totals(width: 100%)), view)`
/// -> dictionary
#let adjust(ctx, ..patches)
```

### 2.5 `theme.custom`: the patch DSL

Rules:

- one helper per schema group, and the helper name equals the group name;
- every parameter defaults to `auto` (untouched), and `none` means off;
- every helper returns a **one-element array**, so any number of helpers in one block all apply
  (verified: two `colors(..)` calls in one block both apply);
- `tests/coverage.typ` asserts helper parameters == schema keys.

| Helper                                                | Group   | Parameters                                                                                                                      |
| ----------------------------------------------------- | ------- | ------------------------------------------------------------------------------------------------------------------------------- |
| `colors`                                              | tokens  | primary, accent, on-primary, on-accent, accent-text, text, muted, subtle, rule, surface, paper, negative, positive, label, mark |
| `fonts`                                               | tokens  | body, heading, numeric, regulated, figures                                                                                      |
| `sizes`                                               | tokens  | base, small, fine, large, title                                                                                                 |
| `weights`                                             | tokens  | strong, regular                                                                                                                 |
| `strokes`                                             | tokens  | hairline, thin, regular, thick                                                                                                  |
| `spacing`                                             | tokens  | xs, sm, md, lg                                                                                                                  |
| `logo`                                                | options | image, height                                                                                                                   |
| `sender`                                              | options | show-extra                                                                                                                      |
| `title`                                               | options | layout, show-place-date, fill                                                                                                   |
| `items-table`                                         | options | zebra, header-fill, header-text, rule, group-fill, column-order, repeat-header                                                  |
| `totals`                                              | options | width, emphasis-fill                                                                                                            |
| `bank-details`                                        | options | qr, qr-size                                                                                                                     |
| `page-number`                                         | options | from, format                                                                                                                    |
| `continuation`                                        | options | show-subject                                                                                                                    |
| `row` _(experimental)_                                | options | fill                                                                                                                            |
| `page`                                                | layout  | paper, flipped, margin, body-top, body-gap, header-ascent, footer-descent                                                       |
| `stationery(value)`                                   | layout  | `"generated"`, `"pre-printed"` or `(first:, rest:)`                                                                             |
| `marks(none)` / `marks(..fields)`                     | layout  | fold, punch, x, length, stroke                                                                                                  |
| `region(name, ..fields)` / `region(name, none)`       | layout  | the region fields (§3.4)                                                                                                        |
| `part(name, renderer)`                                | parts   | `(ctx, view) => content` or `none`                                                                                              |
| `wrap(name, wrapper)`                                 | parts   | `(ctx, view, inner) => content`                                                                                                 |
| `checks`                                              | checks  | min-contrast                                                                                                                    |
| `brand(color:, accent:, font:, heading-font:, logo:)` | macro   | emits colors + fonts + logo                                                                                                     |
| `from-data(data, assets: none)`                       | data    | brand file → patch                                                                                                              |
| `replace(value)`                                      | marker  | replace a dict wholesale                                                                                                        |

Helper names shadow component and Typst names (`title`, `page`, `bank-details`) only inside
the documented scoped `{ import theme.custom: * .. }` block, exactly as with `locale.custom`.

### 2.6 `themed`

```typst
/// Re-themes a subtree with the same patches as `theme.custom`. Derived tokens
/// re-derive inside the scope. Layout patches and named arguments panic.
/// -> content
#let themed(..patches, body)
```

It is an unnamed compute motif: `sys.path` is not extended, so `group`/`item` parent guards keep
working inside it. `apply` stays the shallow data-scoping primitive, and the docs say "not for
theming".

### 2.7 Passing it

```typst
#show: invoice.with(theme: theme.classic)                                          // default
#show: invoice.with(theme: theme.classic.with(layout: theme.layout.us-letter-10))  // page master
#show: invoice.with(theme: theme.modern.with(acme-brand))                          // brand = patch array
#show: invoice.with(theme: theme.minimal.with(pkg.patch, layout: pkg.layout))      // zero-import package
```

---

## 3. Schemas (complete key listing)

The schema is written once in `src/theming/schema.typ` as `field(default, ..types)` leaves.
The `defaults` and `types` trees are derived from it mechanically. In `tokens`, `options` and
the marked layout fields, **a function value is a derivation** `t => value` (with `t` the
resolved tokens), unless the field's types include `function`, in which case it is a callback.

### 3.1 The resolved theme (the value parts see in `ctx.theme`)

| Key            | Type                                                        | Tier         | Meaning                                                    |
| -------------- | ----------------------------------------------------------- | ------------ | ---------------------------------------------------------- |
| `kind`         | `"invoice-pro/theme"`                                       | stable       | assertion tag, checked by `invoice()`                      |
| `meta`         | `(name: str, schema: version-str)`                          | stable       | provenance                                                 |
| `env`          | `(kind: str, lang: str, region: str, zugferd: none \| str)` | stable       | injected context                                           |
| `layout`       | layout (§3.3), derivations resolved                         | stable       | page master                                                |
| `parts`        | `dict<str, function \| none>`                               | stable names | renderers (§3.6); open for custom names                    |
| `tokens`       | §3.2, fully resolved (no functions, no `auto`)              | **frozen**   | what parts read                                            |
| `options`      | §3.5, resolved                                              | provisional  | per-part knobs                                             |
| `checks`       | §3.7                                                        | stable       | validation switches                                        |
| `spec`, `base` | –                                                           | internal     | the unresolved tree (for `themed`) and the injected schema |

### 3.2 Tokens: frozen semantic tier (35 leaves)

| Path                 | Type                            | Default                                     | Meaning                                                        |
| -------------------- | ------------------------------- | ------------------------------------------- | -------------------------------------------------------------- |
| `colors.primary`     | color                           | `#1f2937`                                   | seed 1 (brand colour)                                          |
| `colors.accent`      | color                           | `t => t.colors.primary`                     | seed 2                                                         |
| `colors.on-primary`  | color                           | `t => on-color(primary)`                    | black or white by WCAG contrast                                |
| `colors.on-accent`   | color                           | `t => on-color(accent)`                     |                                                                |
| `colors.accent-text` | color                           | `t => legible(accent, paper)`               | accent usable as text, ≥ 4.5:1                                 |
| `colors.text`        | color                           | `black`                                     | body text                                                      |
| `colors.muted`       | color                           | `luma(100)`                                 | descriptions, notes                                            |
| `colors.subtle`      | color                           | `luma(80)`                                  | sub-labels                                                     |
| `colors.rule`        | color                           | `black`                                     | rules                                                          |
| `colors.surface`     | color \| none                   | `t => surface-of(primary)`                  | zebra and soft fills; the default seed gives exactly `#e2e8f0` |
| `colors.paper`       | color                           | `white`                                     | background assumed for contrast                                |
| `colors.negative`    | color                           | `#b22222`                                   | discounts                                                      |
| `colors.positive`    | color                           | `#333333`                                   | surcharges                                                     |
| `colors.label`       | color                           | `#475569`                                   | tax labels                                                     |
| `colors.mark`        | color                           | `black`                                     | fold and punch marks                                           |
| `fonts.body`         | str \| array                    | `"Liberation Sans"`                         | fallback chain                                                 |
| `fonts.heading`      | str \| array                    | `t => t.fonts.body`                         |                                                                |
| `fonts.numeric`      | str \| array                    | `t => t.fonts.body`                         | amount columns                                                 |
| `fonts.regulated`    | str \| array                    | `("Liberation Sans", "Arial", "Helvetica")` | brand-immune zones (QR-bill)                                   |
| `fonts.figures`      | `"tabular"` \| `"proportional"` | `"tabular"`                                 | `number-width` in amount columns (R4)                          |
| `sizes.base`         | length                          | `10pt`                                      |                                                                |
| `sizes.small`        | length                          | `0.85em`                                    |                                                                |
| `sizes.fine`         | length                          | `7pt`                                       | return line, footer; validated ≥ 6 pt (DIN)                    |
| `sizes.large`        | length                          | `1.2em`                                     | total emphasis                                                 |
| `sizes.title`        | length                          | `1.4em`                                     |                                                                |
| `weights.strong`     | str \| int                      | `"bold"`                                    | the single bold mechanism                                      |
| `weights.regular`    | str \| int                      | `"regular"`                                 |                                                                |
| `strokes.hairline`   | length                          | `0.25pt`                                    | thicknesses; paint comes from colour roles                     |
| `strokes.thin`       | length                          | `0.5pt`                                     |                                                                |
| `strokes.regular`    | length                          | `1pt`                                       |                                                                |
| `strokes.thick`      | length                          | `2pt`                                       |                                                                |
| `spacing.xs`         | length                          | `0.2em`                                     |                                                                |
| `spacing.sm`         | length                          | `0.4em`                                     | cell inset                                                     |
| `spacing.md`         | length                          | `0.6em`                                     | header inset, region gap                                       |
| `spacing.lg`         | length                          | `1em`                                       |                                                                |

Strokes are composed at the use site as `thickness + paint`, so no stroke-dict folding is
needed. Tokens grow only additively after 0.5.0.

### 3.3 Layout (page master)

| Key                               | Type                                                                                                            | Default (base)                                                               | Meaning                                                                                         |
| --------------------------------- | --------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------- |
| `name`                            | str                                                                                                             | `"plain"`                                                                    | shown in errors                                                                                 |
| `paper`                           | str \| `(width: length, height: length)`                                                                        | `"a4"`                                                                       | `a4`, `a5`, `us-letter`, `us-legal` or a custom size                                            |
| `flipped`                         | bool                                                                                                            | `false`                                                                      | landscape                                                                                       |
| `margin`                          | sides `(top, right, bottom, left)`                                                                              | `20/20/20/25 mm`                                                             | text area (all pages); **folds** partial patches                                                |
| `header-ascent`, `footer-descent` | relative                                                                                                        | `30%`                                                                        | passed to `set page`                                                                            |
| `body-top`                        | auto \| length                                                                                                  | `auto`                                                                       | page-absolute y of the first-page body; `auto` = below the lowest reserving region + `body-gap` |
| `body-gap`                        | length                                                                                                          | `4.23mm`                                                                     |                                                                                                 |
| `stationery`                      | `"generated"` \| `"pre-printed"` \| `(first: content, rest: content)`                                           | `"generated"`                                                                | anything else drops `brand: true` regions; the dict form draws the art stretched to the sheet   |
| `marks`                           | none \| `(fold: array<length>, punch: none \| length, x: length, length: length, stroke: stroke \| derivation)` | `none` (template for re-hydration: `((), none, 5mm, 2.5mm, 0.25pt + black)`) | read by the `marks` part                                                                        |
| `regions`                         | `dict<str, region \| none>`                                                                                     | `(:)`                                                                        | ordered, open names, closed records; `none` = removed                                           |

### 3.4 Region (closed record)

| Key                | Type                                                                                                                | Default             | Meaning                                                                                                                        |
| ------------------ | ------------------------------------------------------------------------------------------------------------------- | ------------------- | ------------------------------------------------------------------------------------------------------------------------------ |
| `place`            | `"fixed"` \| `"before"` \| `"after"` \| `"header"` \| `"footer"` \| `"background"` \| `"foreground"`                | `"fixed"`           | fixed = page-absolute rectangle; before/after = in the body flow; header/footer = running; background/foreground = page layers |
| `pages`            | `"all"` \| `"first"` \| `"rest"` \| `"last"` \| `"not-last"`                                                        | `"first"`           | not allowed on before/after (validated)                                                                                        |
| `x` \| `right`     | auto \| length \| relative                                                                                          | `auto`              | fixed: exactly one of the two                                                                                                  |
| `y` \| `bottom`    | auto \| length \| relative                                                                                          | `auto`              | fixed: exactly one of the two; `bottom` needs `height`                                                                         |
| `width`, `height`  | auto \| length \| relative                                                                                          | `auto`              | auto width = paper (fixed) or text width (flow)                                                                                |
| `parts`            | array<part name \| content \| `(ctx, view) => content`>                                                             | `()`                | **reading order**                                                                                                              |
| `arrange`          | `"stack"` \| `"row"` \| `(columns: .., align: ..)` \| `(rows: .., align: ..)` \| `(ctx, cells) => content` _(exp.)_ | `"stack"`           |                                                                                                                                |
| `gap`              | length                                                                                                              | `0.6em`             |                                                                                                                                |
| `align`, `inset`   | alignment, inset                                                                                                    | `top + left`, `0pt` |                                                                                                                                |
| `fill`, `stroke`   | paint/stroke \| none \| derivation                                                                                  | `none`              | e.g. `fill: t => t.colors.primary` (band)                                                                                      |
| `text`             | dict of `set text` args (values may be derivations)                                                                 | `(:)`               |                                                                                                                                |
| `brand`            | bool                                                                                                                | `false`             | brand furniture: dropped unless stationery is `"generated"`                                                                    |
| `isolate` _(exp.)_ | bool                                                                                                                | `false`             | regulated zone: default tokens, `fonts.regulated`, black, white fill                                                           |
| `float` _(exp.)_   | bool                                                                                                                | `false`             | `after` only: float to the paper's bottom edge (reserved zone)                                                                 |
| `reserve`          | auto \| bool                                                                                                        | `auto`              | pushes `body-top` down; auto = yes for first-page fixed regions and first-page background regions with a height                |

**Standard region names.** Every built-in layout defines `marks`, `letterhead`, `address`,
`title`, `continuation`, `page-number` and `footer`. `info`, `references` and reserved zones are
optional. Looks may only patch standard names (CI matrix).

**Layout presets** (DIN A shown in full; the others are in the prototype's `layouts.typ`):

```typst
#let din-5008-a = (
  name: "din-5008-a", paper: "a4",
  margin: (top: 20mm, right: 20mm, bottom: 32mm, left: 25mm),
  marks: (fold: (87mm, 192mm), punch: 148.5mm, x: 5mm, length: 2.5mm, stroke: 0.25pt + black),
  regions: (
    marks: (place: "background", pages: "all", parts: ("marks",)),
    letterhead: (x: 25mm, y: 8mm, width: 165mm, height: 19mm, brand: true,
      parts: ("logo", "sender"), arrange: (columns: (1fr, auto), align: (left + horizon, right + top))),
    address: (x: 20mm, y: 27mm, width: 85mm, height: 45mm, inset: (left: 5mm),
      parts: ("return-address", "recipient"),
      arrange: (rows: (17.7mm, 27.3mm), align: (left + bottom, left + top))),
    info: (x: 125mm, y: 32mm, width: 75mm, height: 40mm, parts: ("sender-extra",)),
    references: (place: "before", parts: ("references",)),
    title: (place: "before", parts: ("title",)),
    continuation: (place: "header", pages: "rest", parts: ("continuation",)),
    page-number: (place: "footer", pages: "all", parts: ("page-number",), align: right),
    footer: (place: "footer", pages: "all", brand: true,
      parts: ("company", "contact", "register", "bank-account"), arrange: (columns: (1fr,) * 4)),
  ),
)
#let din-5008-b = derive(din-5008-a, (layout: (name: "din-5008-b", marks: (fold: (105mm, 210mm)),
  regions: (letterhead: (height: 37mm), address: (y: 45mm), info: (y: 50mm)))))
```

`derive` uses the same layout-patch engine: regions merge field-wise, and nested `+` is never
needed.

| Layout                         | Status       | Notes                                                                           |
| ------------------------------ | ------------ | ------------------------------------------------------------------------------- |
| `din-5008-a`, `din-5008-b`     | stable       | the letter-pro geometry, now owned by invoice-pro                               |
| `us-letter-10`                 | stable       | Letter, #10 window at 0.875 in / 2 in, tri-fold marks                           |
| `a4-digital`, `letter-digital` | stable       | no window, no marks, everything in the flow                                     |
| `plain`                        | stable       | standard regions empty except `title` and `address` (flow)                      |
| `sn-010130-right` / `-left`    | experimental | right-anchored window, `qr-bill` reserved zone; mm values need Swiss Post masks |
| `nf-z-11-001`, `uk-c5`         | experimental | need mask verification                                                          |

### 3.5 Options (provisional component tier; a part reads only its own key)

| Path                        | Type                                               | Default                                                 |
| --------------------------- | -------------------------------------------------- | ------------------------------------------------------- |
| `logo.image`                | none \| content                                    | `none` (an `image` needs `alt`)                         |
| `logo.height`               | length                                             | `14mm`                                                  |
| `sender.show-extra`         | bool                                               | `true`                                                  |
| `title.layout`              | `"line"` \| `"stacked"`                            | `"line"`                                                |
| `title.show-place-date`     | bool                                               | `true`                                                  |
| `title.fill`                | color                                              | `t => t.colors.text`                                    |
| `items-table.zebra`         | array `(odd, even)` of none \| color \| derivation | `(none, t => t.colors.surface)`                         |
| `items-table.header-fill`   | none \| color                                      | `none`                                                  |
| `items-table.header-text`   | auto \| color                                      | `auto` (= on-colour of the fill, else `text`)           |
| `items-table.rule`          | color                                              | `t => t.colors.rule`                                    |
| `items-table.group-fill`    | none \| color                                      | `none`                                                  |
| `items-table.column-order`  | array                                              | `("quantity", "unit-price", "tax-rate", "total-price")` |
| `items-table.repeat-header` | bool                                               | `true`                                                  |
| `totals.width`              | ratio \| relative \| length                        | `66%`                                                   |
| `totals.emphasis-fill`      | none \| color                                      | `none`                                                  |
| `bank-details.qr`           | bool                                               | `true`                                                  |
| `bank-details.qr-size`      | length (absolute)                                  | `25mm` (core clamps to ≥ 20 mm)                         |
| `page-number.from`          | int                                                | `2`                                                     |
| `page-number.format`        | auto \| `(current, total) => content`              | `auto` (locale `strings.document.page`)                 |
| `continuation.show-subject` | bool                                               | `true`                                                  |
| `row.fill` _(exp.)_         | none \| color                                      | `none` (captured by group/item in `themed`)             |
| `custom`                    | dict (open)                                        | `(:)` (third-party parts)                               |

A renamed option keeps its old path as an alias for one minor version. Resolution maps the old
key to the new one and the validator names both.

### 3.6 Parts (names frozen)

| Part                                                                           | Called by                                   | View                         | Required                                                              |
| ------------------------------------------------------------------------------ | ------------------------------------------- | ---------------------------- | --------------------------------------------------------------------- |
| `logo`, `sender`, `sender-extra`, `return-address`, `references`, `info-block` | frame                                       | frame view                   | –                                                                     |
| `recipient`                                                                    | frame                                       | frame view                   | **yes**: hosted exactly once on page 1 or in the flow; non-empty      |
| `title`                                                                        | frame                                       | frame view                   | **yes**: hosted on page 1 or in the flow; non-empty (number and date) |
| `company`, `contact`, `register`, `bank-account`                               | frame                                       | frame view                   | – (legal footer blocks, #18)                                          |
| `page-number`, `continuation`, `marks`                                         | frame                                       | frame view (+ `page`)        | –                                                                     |
| `qr-bill` _(reserved, exp.)_                                                   | frame                                       | frame view                   | –                                                                     |
| `line-items`                                                                   | line-items component                        | line-items view              | not `none` (composite: table + totals)                                |
| `items-table`, `totals`                                                        | `line-items` part                           | line-items view              | not `none`                                                            |
| `notices`                                                                      | line-items component (outside `line-items`) | line-items view + `required` | not `none`; empty while required panics                               |
| `bank-details`                                                                 | bank-details component                      | bank view                    | not `none`                                                            |
| `payment-goal`, `signature`                                                    | their components                            | their views                  | –                                                                     |

### 3.7 Checks

| Path                  | Type          | Default | Meaning                                                                               |
| --------------------- | ------------- | ------- | ------------------------------------------------------------------------------------- |
| `checks.min-contrast` | none \| float | `none`  | panic when a checked pair is below the value (built-in presets are CI-checked at 4.5) |

### 3.8 Views (the frozen data contract; bold = frozen in 0.5.0)

**Frame view**, built by root from its fresh draw ctx as an explicit record (no `ctx.global`):

- **`document`**: `(kind, title, subject, number, date: str, place)`. `kind` is `"invoice"`
  now; quote, credit note and reminder come later.
- **`sender`**, **`recipient`**: normalized parties. The sender gains the new keys `register`,
  `management`, `capital`, `phone`, `email`, `web`.
- **`references`**: normalized `(label, value)` pairs.
- **`bank`**: bank signal or none.
- **`totals`**: `(net, gross, due, prepaid)`, each `(value: decimal, text: str)`.
- **`page`**: `none` in the flow, `(current, total)` in running regions.
- `layout`, `region`: `(name, width, height)`.

**Body views v2** (M3):

- every amount, rate and date is `(value, text)`;
- plural names (`surcharges`), `formatted` instead of `formated`;
- `name`/`description` are content, `label` is content or none;
- `notices: array<(kind, text, marker)>` decided in measure; `taxes` pre-filtered (0 %);
- `bank.qr: none | (size) => content`, built in measure (EUR only, ≥ 0.10, black on white,
  ≥ 20 mm).

The line-items view as a whole stays provisional until the table rewrite. Parts must not read
`ctx.global`.

---

## 4. Cascade, precedence & merge

### 4.1 Layers

| #   | Layer                          | Written as                                                               | Scope                                |
| --- | ------------------------------ | ------------------------------------------------------------------------ | ------------------------------------ |
| L0  | schema defaults                | injected `base`                                                          | document                             |
| L1  | **layout**                     | preset default or `layout:` (last wins)                                  | document                             |
| L2  | look                           | `build-theme(.., look)`                                                  | document                             |
| L3  | positional patches, call order | `.with(brand, tweaks)`, chained `.with` appends                          | document                             |
| L4  | scopes, innermost wins         | `themed(..)[..]`                                                         | subtree: tokens/options/parts/checks |
| L5  | explicit component args        | `bank-details(qr-code: (display: false))`, `line-items(show-column: ..)` | one instance                         |

The layout is not ordered by call position. It is always L1, because it is the page master the
patches describe. A patch such as `region("address", y: 50mm)` therefore always lands on the
final layout, wherever it appears in the chain. That is the locale semantics: region patches
apply to whatever region results. L5 rule: _what_ is shown (columns, QR yes/no) stays on
components. A component argument with a theme counterpart defaults to `auto` = inherit (loom
`derive`). Native Typst rules stay outside the chain: body rules win over theme rules, and
rules placed before `#show: invoice` lose. The frame issues only `set text(font, size, fill)`,
`show heading: set text(font)` and `set par(justify)`.

### 4.2 Merge rules (`utils/patch.typ`, shared with locale)

| Patch value                              | Effect                                                                                                       |
| ---------------------------------------- | ------------------------------------------------------------------------------------------------------------ |
| `auto`                                   | untouched, at every depth                                                                                    |
| `none`                                   | a real value "off"; on a region, removes it                                                                  |
| dict onto dict                           | recurse, unlimited depth; an unknown key panics with the `::` path, a did-you-mean hint and the allowed keys |
| anything onto `layout::margin`           | folds: `(bottom: 35mm)`, `x`, `y`, `rest`                                                                    |
| dict onto a `none` group with a template | re-hydrate (`marks(fold: ..)` on a digital layout)                                                           |
| `wrap(fn)`                               | `(ctx, view) => fn(ctx, view, previous)`; wraps stack across L2–L4                                           |
| `replace(v)`                             | wholesale                                                                                                    |
| arrays, scalars, content, functions      | replace                                                                                                      |
| region patch on an existing name         | field-wise merge, keys checked against the region schema                                                     |
| region patch on a new name               | needs `place`; otherwise a did-you-mean panic against the existing regions                                   |
| open maps                                | `parts` names, `options.custom`, region names                                                                |

Patches that are not dicts panic (`patch #2 must be a dictionary ...`). `none` in a patch list
(from a false `if` in a block) is ignored. Unknown groups panic with a hint.

### 4.3 Derivation

Resolution is a fixpoint:

1. Round 0 replaces function leaves with a typed placeholder.
2. Each round evaluates every derivation against the previous tree.
3. It stops when nothing changes, after at most 6 rounds.
4. If it does not settle, it panics (`derivations do not settle ... (a derivation cycle)`).

A user can therefore reference any token from any other token without knowing an order. This
fixes locale-symmetry's positional trap without tokens-first's string aliases. Literal leaves
are type-checked **before** derivations run, so a wrong literal is reported, not a crash deep
inside `on-color("#ff0000")`. Options derive once from the resolved tokens. Region
`fill`/`stroke`/`text` and `marks.stroke` may derive too.

### 4.4 When, and what it costs

- **The document theme resolves once**, in `invoice()`, before `weave`. It is a pure function,
  memoised by comemo.
- **`themed` re-resolves** from `spec` once per scope per loom pass.
- **The theme travels sealed** in one ctx key, `metadata(theme)`, so loom's per-closure-call
  argument hashing does not scale with theme size. Parts always receive `ctx` with the theme
  unsealed.
- **Measured at 150 items:** +8 % sealed vs +67 % unsealed (§10).

---

## 5. Renderer / part contract and where compliance output lives

### 5.1 Signature

Every part is `(ctx, view) => content`, and a wrapper is `(ctx, view, inner) => content`. A
wrapper may transform the view, or re-parameterise the inherited renderer with
`theme.adjust(ctx, ..patches)`. `ctx.theme` inside a part is the effective, possibly scoped,
theme as a plain dict.

```typst
part("signature", (ctx, view) => [— #view.name])                                    // replace
wrap("bank-details", (ctx, view, inner) =>
  block(fill: ctx.theme.tokens.colors.surface, inset: 8pt, inner(ctx, view)))        // wrap
wrap("totals", (ctx, view, inner) =>
  inner(theme.adjust(ctx, theme.custom.totals(width: 100%)), view))                   // re-parameterise
part("totals", (ctx, view) => { /* copy of theme.parts.totals, edited */ })          // eject
```

### 5.2 Stability tiers

| Tier                                         | Contents                                                                                                                                                                                                                                    |
| -------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Frozen**                                   | calling convention; `layout:` swap; helper names; merge rules; token paths; layout and region schema; standard region names; part names and signature; bold view fields; required parts and roles; `themed`, `build-theme`, `resolve-theme` |
| **Provisional** (rename alias for one minor) | options (§3.5), the line-items view                                                                                                                                                                                                         |
| **Experimental**                             | `arrange` functions, `isolate`, `float` reserved zones, `row` capture, `qr-bill`, SN/NF/UK layouts, `adjust`                                                                                                                                |
| **Internal**                                 | every other ctx key (`ctx.global`, `ctx.item-data`), `spec`, `base`, sealing, the generic table renderer                                                                                                                                    |

### 5.3 Compliance output (never in a part)

| Output                                                     | Lives in                                                                            | Why no theme can lose it                                                                               |
| ---------------------------------------------------------- | ----------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------ |
| PDF metadata (title, author, date, keywords incl. ZUGFeRD) | `root.draw`, before the frame                                                       | no theme code has run yet; `plain` passes `ua-1` (verified)                                            |
| `text.lang`/`region`                                       | root, plus the `build-locale` lang fix (S-17)                                       | "Seite/Page/Page … sur" follows the locale (verified)                                                  |
| factur-x.xml                                               | `root.draw` `pdf.attach`                                                            | parts are draw-only (verified under `a-3b`)                                                            |
| legal notes                                                | decided by the component; `notices` appended **outside** the `line-items` composite | replacing `line-items` cannot drop them; `none` refused; empty output while required panics (verified) |
| 0 % tax suppression                                        | measure (`view.taxes`)                                                              | parts see only rows that must be shown                                                                 |
| EPC-QR payload                                             | bank-details measure → `view.qr(size)`                                              | a part places it; black on white, ≥ 20 mm (built)                                                      |
| invoice identity (title, number, date)                     | required role `title`                                                               | must be hosted on page 1 or in the flow; empty output panics (verified)                                |
| recipient address                                          | required role `recipient`                                                           | exactly once in a first-page or flow region (tagged, reading order); overlap lint for the window       |
| regulated zones                                            | `isolate` region                                                                    | default tokens, `fonts.regulated`, black on white; covers marks and stationery                         |
| legal footer on a reserved page                            | frame                                                                               | relocated into the flow above the zone, not dropped (built)                                            |

---

## 6. Page frame & arbitrary formats

The frame (`theming/frame.typ`, 217 lines, replacing letter-pro) issues **one unconditional
top-level `set page`**. It then renders, in order:

1. `background`: stationery (stretched to the sheet) and background regions (marks, bands,
   rails).
2. First-page `fixed` regions, placed **in flow**, so they are tagged and read in region order.
3. A spacer to `body-top`.
4. `before` regions.
5. The body (`par(justify)`).
6. Non-floating `after` regions.
7. Reserved zones.

Running regions (`header`/`footer`) are drawn per page in `context` with `view.page`. Fixed
regions for other page sets go into the foreground as artifacts.

| Requirement                         | How                                                                                                        |
| ----------------------------------- | ---------------------------------------------------------------------------------------------------------- |
| paper & margins (R9)                | `page(paper:, margin:)`; per-page margins are impossible in Typst, so page 1 differs via `body-top`        |
| window geometry (R10)               | the `address` region; national presets are data; a company window is one `region("address", x: ..)`        |
| marks (R12)                         | `layout.marks` + the `marks` part; `marks(none)` = digital                                                 |
| first vs following pages (R13, R17) | `pages` on every region; `continuation` header on `"rest"`                                                 |
| letterhead paper (R13, R14)         | `stationery(..)`: one value, drops `brand` regions whatever renders them                                   |
| legal footer (R15, #18)             | the `footer` region hosts block parts, content and functions; every page                                   |
| page numbering (R16)                | the `page-number` part, locale key `strings.document.page`, options `from`/`format`                        |
| logo position (R2, R19)             | the order of `letterhead.parts` or a different region, as data                                             |
| full-bleed band (R20)               | a layout region `place: "background", x: 0mm, width: 100%, height: ..`, which reserves space automatically |
| regulated zones (R18)               | an `after` region with `float` + `isolate` + `height`; page footers relocate above it                      |
| stamps (R26)                        | a `foreground` region hosting content (`"KOPIE"`)                                                          |

**A new format without forking** is a layout dict, optionally with custom parts. **Third-party
packages** ship a layout dict, parts that read `ctx.theme.tokens` and `view`, and patch dicts,
including wrap markers written as the documented tagged dict. They import **nothing** from
invoice-pro, so the version-bound loom key never bites. The user writes
`theme.minimal.with(pkg.patch, layout: pkg.layout)`. The running invoice-pro injects its
schema, and keys added later arrive with their defaults.

---

## 7. Walkthroughs

**P1: Freelancer, digital only, five minutes** (`tests/walk.typ p=p1`)

```typst
#show: invoice.with(
  theme: theme.classic.with(
    theme.custom.brand(color: rgb("#0f766e"), font: ("Inter", "Liberation Sans"),
      logo: image("logo.svg", alt: "Studio Lina Berg")),
    theme.custom.marks(none),
  ),
  locale: locale.de-de, tax-exempt-small-biz: true, ..
)
```

The zebra, header text and accent text all re-derive from the one colour.

**P2: GmbH, pre-printed + digital twin + ZUGFeRD, § 35a footer** (`tests/p2-stationery.typ`, 3 modes)

```typst
#let mode = sys.inputs.at("output", default: "pdf")          // print | pdf | einvoice
#let acme = theme.custom.brand(color: rgb("#003a70"), accent: rgb("#e2001a"),
  font: ("Source Sans 3", "Liberation Sans"), logo: image("acme.svg", alt: "ACME Maschinenbau GmbH"))
#show: invoice.with(
  theme: theme.classic.with(acme, layout: theme.layout.din-5008-b, {
    import theme.custom: *
    stationery(if mode == "print" { "pre-printed" }
      else if mode == "pdf" { (first: image("lh-1.svg"), rest: image("lh-2.svg")) }   // SVG: PDF/A-safe
      else { "generated" })
    if mode != "print" { marks(none) }
  }),
  sender: (name: "ACME Maschinenbau GmbH", .., register: [Amtsgericht Stuttgart HRB 12345],
           management: [GF: Dr. Erika Muster, Max Beispiel], vat-id: "DE123456789"),
  zugferd: if mode == "einvoice" { "en16931" },
)
```

- **print:** keeps window and marks, drops letterhead and footer.
- **pdf:** SVG art first and rest.
- **einvoice:** generated furniture and the § 35a footer from the `register` block. A `.pdf`
  letterhead with `zugferd` panics early.

**P3: Swiss SME, right window, QR-bill** (experimental layout; `out/m-classic-sn-010130-right-*`)

```typst
#show: invoice.with(locale: locale.de-ch,
  theme: theme.classic.with(layout: theme.layout.sn-010130-right,
    theme.custom.brand(color: rgb("#7a1f2b"), font: ("Source Serif 4", "Libertinus Serif"),
      logo: image("logo.svg", alt: "Treuhand Aare AG"))))
// left-window envelopes: theme.custom.region("address", right: auto, x: 22mm)
```

The slip keeps `fonts.regulated` and black. When it does not fit, it floats to the next page,
and the legal footer moves above it (verified on 2 pages).

**P4: Agency, 12 white-label brands in TOML** (`tests/walk.typ p=p4`)

```toml
[theme.tokens.colors]
primary = "#0b3d91"
accent = "#ffb000"
[theme.options.logo]
image = "nordlicht.svg"
height = "9mm"
[theme.options.items-table]
header-fill = "{colors.primary}"
zebra = ["none", "none"]
[theme.layout]
margin = { bottom = "35mm" }
```

```typst
#let e = toml("brands/" + job.brand + ".toml")
#show: invoice.with(theme: theme.modern.with(
  theme.custom.from-data(e.theme, assets: p => image("brands/" + p, alt: e.sender.name))),
  sender: e.sender, ..job.header)
```

A key typo fails with `theme::tokens::colors has unknown key `primry`. Did you mean `primary`? ...`.

**P5: SaaS batch pipeline**

```typst
// theme.typ: built once, imported everywhere (an immutable value)
#let company = theme.minimal.with(theme.custom.from-data(json("design/brand.json")),
  theme.custom.checks(min-contrast: 4.5))
// invoice.typ
#show: invoice.with(theme: company.with(layout: if d.region == "us" { theme.layout.letter-digital }
  else { theme.layout.a4-digital }), locale: locale.at(d.locale), zugferd: "en16931", ..d.header)
// typst compile --pdf-standard a-3a,ua-1 --font-path fonts ...
```

Choosing the layout is explicit. `theme.resolve-theme(company)` goes in the pipeline's unit
tests.

**P6: Design studio, band look on DIN B, wrap + replace** (`tests/walk.typ p=p6`)

```typst
#show: invoice.with(theme: theme.modern(layout: theme.layout.din-5008-b, {  // called == .with
  import theme.custom: *
  brand(color: rgb("#111827"), accent: rgb("#6366f1"), font: "Inter", heading-font: "Fraunces",
        logo: image("mark-white.svg", alt: "Atelier Nord"))
  region("letterhead", parts: ("sender", "logo"))                          // logo right: data
  wrap("totals", (ctx, view, inner) => block(stroke: (left: 3pt + ctx.theme.tokens.colors.accent),
    inset: (left: 6pt), inner(theme.adjust(ctx, totals(width: 100%, emphasis-fill: none)), view)))
  part("payment-goal", (ctx, view) => block(fill: ctx.theme.tokens.colors.accent.lighten(88%),
    inset: 1em, text(size: 1.2em)[Fällig in #view.days Tagen: *#(ctx.locale.format.currency)(view.total)*]))
}))
```

**P7: Accessibility-bound supplier**

```typst
#show: invoice.with(theme: theme.classic.with(
  theme.custom.brand(color: rgb("#00843d"), logo: image("sw.svg", alt: "Stadtwerke Musterstadt")),
  theme.custom.checks(min-contrast: 4.5), theme.custom.marks(none)))
// typst compile --pdf-standard a-3a,ua-1
```

Metadata and `lang` come from core. The logo without alt text panics. The recipient and title
are tagged in reading order, and furniture is artifacts. The built-in presets have zero
contrast failures at 4.5 (CI).

**P8: US subsidiary, same brand** (`tests/walk.typ p=p8`)

```typst
#import "corporate.typ": corporate                    // the same patch array as in P2
#show: invoice.with(locale: locale.en-us, theme: theme.classic.with(corporate,
  layout: theme.layout.us-letter-10,
  theme.custom.region("footer", parts: ([*Remit to:* ACME Inc., PO Box 12, Austin TX],
    [billing\@acme.com], "register"), arrange: (columns: (1fr, 1fr, 1fr)))))
```

**(9) Third-party package author** (`tests/third-party.typ` + `tests/pkgs/local/acme-theme`)

```typst
// @preview/acme-theme - NO invoice-pro import
#let sidebar-a5 = (name: "acme-sidebar-a5", paper: "a5", flipped: true, marks: none,
  margin: (top: 12mm, bottom: 14mm, left: 72mm, right: 12mm),
  regions: (
    rail: (place: "background", pages: "all", x: 0mm, y: 0mm, width: 60mm, height: 100%,
      brand: true, parts: ("acme-rail",)),
    title: (place: "before", parts: ("title",)), address: (place: "before", parts: ("recipient",)),
    marks: (place: "background", parts: ()), letterhead: (place: "before", parts: ()),
    continuation: (place: "header", pages: "rest", parts: ()),
    page-number: (place: "footer", pages: "all", parts: ("page-number",), align: right),
    footer: (place: "footer", pages: "all", parts: ())))
#let rail(ctx, view) = block(width: 100%, height: 100%, fill: ctx.theme.tokens.colors.primary, ..)
#let patch = (parts: (acme-rail: rail,
    signature: ("__invoice-pro-wrap__": (ctx, view, inner) => { inner(ctx, view); [Digitally issued.] })),
  tokens: (colors: (primary: rgb("#7c3aed"))), options: (items-table: (zebra: (none, none))))
// user: theme: theme.minimal.with(acme.patch, layout: acme.sidebar-a5)
```

Package CI: `theme.resolve-theme(theme.minimal.with(acme.patch, layout: acme.sidebar-a5))`
against the published invoice-pro.

**(10) Scoped override** (`tests/walk.typ p=scope`)

```typst
#line-items[
  #group([Phase 1])[..]
  #themed(theme.custom.row(fill: rgb("#fef3c7")))[#group([Phase 2 - optional])[..]]   // one group
]
#themed({ import theme.custom: *; colors(primary: rgb("#b91c1c"))
  wrap("bank-details", (ctx, view, inner) => block(fill: ctx.theme.tokens.colors.surface, inset: 8pt, inner(ctx, view)))
})[#bank-details(..)]                        // surface re-derives from the scoped seed
```

---

## 8. Validation & error messages

**When.**

- At helper call: Typst's own `unexpected argument`.
- Once in `invoice()`: groups, keys at every depth, leaf types (literals before derivations),
  derivation cycles, region semantics, part references, required parts and roles, the overlap
  lint, logo alt text, the PDF/A guards (when `zugferd` is set) and contrast (opt-in).
- At each `themed`: the same, and layout patches are rejected.
- At render: required parts returning nothing.

**House style:** a `theme::` path, the value, the allowed set and a did-you-mean hint. All
messages below are real prototype output (`tests/errors/err.typ --input case=N`):

```
theme::tokens::colors has unknown key `primry`. Did you mean `primary`? Allowed keys: primary, accent, on-primary, on-accent, accent-text, text, muted, subtle, rule, surface, paper, negative, positive, label, mark
theme `classic`: unexpected named argument(s) `form`. A theme takes patches (e.g. `.with(theme.custom.colors(primary: teal))`) and `layout:` (e.g. `layout: theme.layout.din-5008-b`).
theme::layout::regions has no region `adress` in layout `din-5008-a`. Did you mean `address`? Existing regions: marks, letterhead, address, info, references, title, continuation, page-number, footer. To ADD a region, give it a `place`.
theme::layout (din-5008-a) must host part `recipient` in exactly one first-page or flow region (found 0). `recipient` carries legally required output (recipient address); restyle it by replacing its renderer, but keep it placed.
theme::layout (a4-digital) must host part `title` in at least one first-page or flow region (found 0). `title` carries legally required output (document title, invoice number and date: § 14 UStG / EN 16931 BT-1, BT-2); restyle it by replacing its renderer, but keep it placed.
theme::parts::notices carries legally required output and cannot be `none`; wrap it or replace its renderer instead
theme::parts::notices returned no content, but it must render legally required output
theme::options::logo::image needs alt text, e.g. image("logo.svg", alt: "ACME GmbH") (mandatory under PDF/UA-1)
theme::layout::regions::stamp overlaps the address window region `address`; move it or shrink it (envelope windows must stay clear)
theme::tokens: derivations do not settle after 6 rounds (a derivation cycle, e.g. `a: t => t.b`, `b: t => t.a`)
theme::tokens: colors::accent-text on colors::paper has contrast 3.53:1, below checks.min-contrast 4.5:1
theme::parts::signatur is neither a built-in part nor hosted by any region. Did you mean `signature`? Add it to a region's `parts`, or check the name.
theme: unknown patch group `colours`. Allowed groups: tokens, options, parts, layout, checks
variable `theme::tokens::colors::primary`("#ff0000") must be of color
theme::layout::paper `a44` has no known size; use (width:, height:). Did you mean `a4`? Known: a4, a5, us-letter, us-legal
variable `invoice::theme` must be of function (a lazy theme such as `theme.classic`), found dictionary. For a brand file write `theme.classic.with(theme.custom.from-data(toml("brand.toml")))`.
theme::layout::stationery::first embeds a PDF image, which PDF/A-3 (ZUGFeRD) cannot contain; convert the letterhead to SVG
theme::layout::regions::title::pages applies only to fixed, header, footer, background and foreground regions; flow regions appear once
theme::custom::from-data: `options::logo::image` is the path "x.svg"; packages cannot open files by path. Pass `assets: p => image(p, alt: ..)` from your document.
themed: layout patches are document-level (the page master cannot change mid-document); pass them to `invoice(theme: ..)`
themed: unexpected named argument(s) `tokens`; pass patches, e.g. themed(theme.custom.colors(primary: red))[..]
```

**Specified, not yet built:**

- CMYK colours with `zugferd` (the code exists; not exercised by a test).
- `sizes.fine < 6pt` (DIN address-zone minimum).
- "the reserved zone plus relocated footer does not fit on any page" (the prototype would
  overflow rather than panic).
- A rename-alias hint.

Typst has no warning API, so contrast is either off (the default) or strict.

---

## 9. Internals sketch

```
invoice(theme:)                                   src/invoice.typ
  type(theme) == function, else panic (points to from-data)
  eval = theme(base: schema, env: (kind, lang, region, zugferd))   -> assert kind tag
  inputs.theme = seal(eval)                       ONE ctx key; metadata() = lazily hashed
  weave(max-passes: 2)
root.draw   set text(lang, region) · references normalized · pdf.attach(factur-x)
            set document(..) · render-frame(ctx, body)                 (compliance first)
frame       unsealed(ctx) · set page · regions → call parts (frame view)
components  call-part(ctx, name, view, required:)   (unseals; required = non-empty)
line-items  call-part("line-items") ; call-part("notices", required)   (outside the composite)
bank        measure builds view.qr(size) (EPC payload, clamp, black on white)
themed      compute-motif scope: seal(scope-theme(theme-of(ctx), patches))
group       measure captures theme-of(ctx).options.row → entry.style   (experimental)
```

**File layout (prototype = proposal):**

- `src/utils/patch.typ` (160 lines, shared with locale)
- `src/theming/`:
  - `schema.typ`: `field()`, token/option/check/region/layout schema, rules
  - `resolve.typ`: fixpoint derivation, per-leaf types
  - `color.typ`: contrast, on-color, legible, surface-of
  - `layout-ops.typ`: region-aware layout patching, `derive`
  - `layouts.typ`: data
  - `build.typ`: `build-theme`, `resolve-theme`, `adjust`, `scope-theme`, finalize
  - `validate.typ`: layout, roles, overlap, parts, assets, contrast
  - `custom.typ`: DSL
  - `data.typ`: `from-data`
  - `presets.typ`: looks and presets
  - `frame.typ`, `scope.typ`, `access.typ` (sealing)
  - `parts/frame.typ`, `parts/body.typ`
- `src/public/theme.typ`, `src/public/layout.typ`
- removed: `src/themes/DIN-5008`, `base-theme/base.typ`, `blank`, and the `@preview/letter-pro`
  import

Total: 1,767 lines, of which about 700 are parts and frame.

**Built-in renderers read only** `ctx.theme.tokens` and `ctx.theme.options.<own>`. Defaults
exist once, in `schema.typ`, which replaces the up to five duplicate default sets. M3 folds the
50-parameter table renderer into direct token reads.

**loom 0.1.1 as-is:** only public API is used (`compute-motif`, ctx inheritance,
`eval-content`). **loom nice-to-haves:**

1. an official opaque ctx value (makes sealing a documented contract);
2. a deep-merge `apply`;
3. an exported `matcher.display` plus `optional()` and a path-reporting `match`;
4. a fix for the labelled-container crash (label hooks on user blocks);
5. an optional version-independent motif key (packages could emit `info.*`);
6. `ensure` distinguishing missing from `none`;
7. the `observer` typo.

**Compiler:** only 0.14-era features are used:

- no `dictionary.map/filter` and no `path()`;
- `array.to-dict`, `oklch`, `color.linear-rgb`, `image` fields `source`/`alt`, `counter(page).final()`,
  `query(<label>)` in page furniture.

The prototype was not run on 0.14.0, so the **M0 CI job on 0.14.0** is mandatory. It must
include the sealing benchmark, because lazy hashing of `metadata` is observed behaviour, not a
documented guarantee. **I do not recommend bumping the minimum compiler.** The `assets:` loader
replaces `path()`.

---

## 10. Feasibility evidence

Prototype root:
`<session>/proto-synthesis/`.
It was forked from structure-first and its engine was rewritten. Commands:
`typst compile --root . tests/<f>.typ out/<name>-{p}.png` (add `--package-path tests/pkgs` for
the third-party test).

| Test                                                                               | Verified                                                                                                                                                                                                                                                                                                                               |
| ---------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `tests/matrix.typ --input look=L --input layout=Y`                                 | **4 looks × 7 layouts = 28/28 compile from one body**; the modern band survives the swap to DIN A/B; SN reserved zone floats to page 2 with the footer relocated above the slip; `out/sheet-matrix.png`                                                                                                                                |
| `tests/p2-stationery.typ --input output=print\|pdf\|einvoice`                      | one switch: pre-printed keeps window and marks and drops letterhead and footer; SVG first/rest stretched to the sheet; generated furniture; `out/sheet-p2.png`                                                                                                                                                                         |
| same, `--pdf-standard a-3b`                                                        | factur-x.xml attached (2 hits), ZUGFeRD keywords from core                                                                                                                                                                                                                                                                             |
| `tests/walk.typ --input p=p1\|p4\|p6\|p8\|scope`                                   | brand macro; TOML via `from-data` incl. alias `"{colors.primary}"`, `"none"`, lengths and the `assets` loader; called form; wrap + `adjust` + part replace + logo right as data; US #10 with content footer blocks; `themed` row capture for one group and a scoped seed that re-derives `surface` inside a wrap; `out/sheet-walk.png` |
| `tests/third-party.typ` + `tests/pkgs/local/acme-theme/0.1.0`                      | zero-import package: A5 landscape layout, custom part reading `ctx.theme.tokens`, wrap marker as a plain dict (`out/third-1.png`)                                                                                                                                                                                                      |
| `tests/coverage.typ`                                                               | helper parameters == schema keys for all 14 groups; block DSL with two helpers of the same group; margin fold; derived on-primary; the **default seed reproduces `#e2e8f0` exactly**; chained later-wins; called == uncalled; layout swap keeps look patches                                                                           |
| `tests/errors/err.typ --input case=1..21`                                          | all 21 messages in §8                                                                                                                                                                                                                                                                                                                  |
| `--pdf-standard ua-1` and `a-3a,ua-1`                                              | classic, modern, plain and the P4 TOML theme compile clean                                                                                                                                                                                                                                                                             |
| `tests/bench-150.typ` vs `proto-judge-maintainer/baseline/jbench-150.typ` (5 runs) | baseline 1129–1156 ms; sealed **1226–1364 ms**; unsealed **1894–1922 ms** (`--input ip-seal=0`)                                                                                                                                                                                                                                        |

**Not verified:**

- typst 0.14.0.
- View v2 (the line-items view is still v1; the EPC payload did move into measure).
- The table rewrite (the header spacer-column gap and the "(net)" colour defect remain).
- Region-level rename aliases.
- `sizes.fine` minimum.
- CMYK guard exercise.
- Whether an oversized reserved zone panics.
- SN/NF/UK millimetres against postal masks.
- The QR-bill component (a placeholder slip only).
- The locale adoption of `patch.typ` (verified separately by locale-symmetry's `tests/dsl.typ`).
- `strings.document.page` in the locale schema (a fallback table is used).

**Visual caveats:**

- In the digital layouts, `title` and `address` stack with little space between them. This is a
  look tweak (`region("address", inset: (top: ..))`).
- The continuation header prints over SVG art that has its own page-2 header. Mark it
  `brand: true` in that case.

---

## 11. Trade-offs, risks & rejected alternatives

**Weaknesses.**

- **Fixed regions are absolute.** Content taller than its rectangle overflows, as with
  letter-pro. `height: auto` and flow regions are the mitigation.
- **More concepts than a knob list.** There are five of them. The ladder hides regions until
  rung 4, and `brand()` covers rung 2.
- **Owning the frame means owning postal correctness.** Non-DIN layouts stay experimental until
  verified.
- **Per-page margins are impossible**, so a tall first-page footer forces `margin.bottom`.
- **Sealing depends on lazy content hashing**, which is observed, not guaranteed. The 0.14.0 CI
  benchmark and a loom opaque-value API are the mitigation.
- **The fixpoint resolution accepts self-consistent cycles**, e.g. `a = darken(b)`, `b = a` on
  black. The result is deterministic, but surprising.
- **Row scoping reaches only per-row styles** (`row.fill`), because a table is drawn once by its
  parent.
- **The default look changes slightly.** Legal footer, continuation header and a derived zebra
  mean about 20 visual refs are reviewed once, in M2.

**Rejected alternatives.**

1. tokens-first's 190 tokens and `ref.*` tier, arrangement enums, `$op` descriptors and dotted
   keys: freeze surface and a second expression language.
2. locale-symmetry's `<style>-<layout>` matrix, positional derivation, layout-as-function-of-style
   and fixed-zone frame: they do not meet decision 2.
3. user-first's 29 knobs, `it =>` signature, `theme: dict` and `kinds:` now: the `.with` traps
   and precedence inversion were verified by the api judge.
4. structure-first's named `tokens:/options:/parts:` shorthands, `frame view.totals = ctx.global`
   and `masthead/parties/band` parts: the parts became regions and options.
5. A replaceable frame part: that is how 0.4 lost metadata and window guarantees.
6. Region inference by default: CH/FR millimetres are unverified.
7. Keeping letter-pro: it blocks R9 and R13–R18.
8. elembic and valkyrie (prior-art D15/D16).

**Experimental in 0.5.0:** see §5.2.

---

## 12. Implementation roadmap (solo maintainer; each milestone shippable)

| M                                 | Scope                                                                                                                                                                                                          | Ships                                          | Tests                                                                                                                |
| --------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------- | -------------------------------------------------------------------------------------------------------------------- |
| **M0** core hygiene               | `utils/patch.typ` adopted by `locale.custom`/`build-locale` (fixes I-1/I-2/I-3); `lang` fix; `set document` + `pdf.attach` in root; **0.14.0 CI job** with the sealing benchmark                               | 0.4.3                                          | patch unit tests; locale block-DSL docs test; en/fr page-label visual; `plain`-style metadata under `ua-1`           |
| **M1** engine behind a shim       | schema/resolve/build/validate/custom/data; sealing; `invoice(theme:)` accepts only lazy themes; parts registry wraps today's slots; the frame shim still calls the old DIN document                            | 0.5.0-dev, no visual churn                     | `tests/coverage.typ`, the §8 compile-fail suite, `resolve-theme` token assertions                                    |
| **M2** own frame + DIN            | `frame.typ`, `din-5008-a/b`, `plain`, frame parts, legal footer blocks (#18), continuation, localized page numbers (`strings.document.page`), stationery, identity guard, overlap lint; **letter-pro removed** | the one visual-ref pass (~20 refs, one by one) | `layout-din-a/b`, `stationery-{print,pdf,einvoice}`, `footer-all-pages`; `a-3b` and `a-3a,ua-1` for built-in presets |
| **M3** views v2 + compliance core | view v2; notices, zero-tax and EPC decided in measure; `notices` outside the composite; table/totals renderers read tokens (drops 50 params, fixes the crash and spacer bugs)                                  | 0.5.0-rc                                       | issue-39/41 rewritten against `wrap("totals")`; `tax-exemption-grounds` asserts `view.notices`                       |
| **M4** looks + layouts            | `modern`, `minimal`; `us-letter-10`, `a4/letter-digital`; SN/NF/UK as experimental data after mask checks                                                                                                      | 0.5.0-rc                                       | look × layout matrix (one ref per built-in layout); zero contrast failures at 4.5                                    |
| **M5** scope + data + guards      | `themed` + `row` capture; `from-data`; PDF/A guards; contrast check; `adjust`                                                                                                                                  | 0.5.0-rc                                       | walkthrough tests as docs tests                                                                                      |
| **M6** docs & lock                | `theme/{index,custom,base,layouts,parts,packages}.md`; schema tables generated from `schema.typ`; every snippet registered with a tytanic test; thumbnail                                                      | **0.5.0 = API lock**                           | docs registry complete                                                                                               |
| 0.5.x                             | `layout.for-region`, QR-bill component in the reserved zone, `specimen`, document kinds (`env.kind` patches), DTCG adapter                                                                                     | –                                              | –                                                                                                                    |

Order rationale:

- M0 has value on its own and proves the patch semantics.
- M1 lands the API shape without visual churn.
- M2 is the only big visual diff.
- M3 removes the crash-prone renderer.
- M4 is data work that users can contribute (PR #40's UK support becomes a layout).

---

## Appendix: Open questions for the maintainer

1. **Singular `theme` namespace** (breaking the `themes` spelling)?
   _Recommendation: yes._ Every call site changes anyway (`themes.DIN-5008()` no longer exists),
   and `theme:`/`theme.` follows the house rule that `locale` sets.
2. **Region-inferred layout (R11)?** _Recommendation:_ none in 0.5.0. Ship
   `theme.layout.for-region(code)` in 0.5.x, mapping only verified layouts (de/at → DIN A,
   us → US #10). Add ch and fr after the masks are checked. Explicit always wins.
3. **Buy or borrow the SN 010130 / NF Z 11-001 specifications** (or Swiss Post control masks)
   before marking those layouts stable? _Recommendation:_ yes. Until then they ship as
   experimental.
4. **New `sender` keys** `register`, `management`, `capital`, `phone`, `email`, `web` for the
   footer blocks (an invoice-header API change)? _Recommendation:_ yes, optional, rendered only
   when present.
5. **New locale key** `strings.document.page: (current, total) => content`? _Recommendation:_
   yes, in M2, with de/en/fr/it/es.
6. **The four hidden table variants** (elegant, vibrant, luxury, informational): port them as
   looks or delete them? _Recommendation:_ delete them in M3. Re-express one of them as a docs
   example of a look, to show the range without freezing four more presets.
7. **Freeze scope of view v2:** freeze the frame, bank, payment and signature views in 0.5.0 and
   keep the line-items view provisional until 0.6? _Recommendation:_ yes.
8. **loom 0.1.2 with an official opaque ctx value?** _Recommendation:_ yes, small and
   same-author. It turns sealing from observed behaviour into a contract. The design does not
   depend on it.
9. **`theme.adjust` name and tier:** _Recommendation:_ ship it as experimental under this name.
   Promote it or rename it at 0.6 based on usage.
10. **Default look drift:** the derived zebra is exact, but the new legal footer and the
    continuation header on the default preset change the refs. Accept them (recommended), or
    ship `classic` without a footer region by default?
