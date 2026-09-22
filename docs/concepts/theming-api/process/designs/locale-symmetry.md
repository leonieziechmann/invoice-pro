# Theming API v0.5.0 — "Designed by the same hand as the locale API"

Key: `locale-symmetry`. Prototype: `scratchpad/proto-locale-symmetry/` (compiles on typst 0.15.1; see §10).

This proposal takes the locale architecture literally. If you know
`locale.en-de.with({ import locale.custom: *; document(invoice: "Proforma") })`,
you should be able to guess
`themes.modern-din-5008-b.with({ import themes.custom: *; palette(primary: teal) })`
without reading any docs. Every locale concept has exactly one theme counterpart, and the
verified locale defects (the block DSL losing patches, the broken strict-merge panic,
the depth-2 wholesale replace) are fixed by **one shared utility, `src/utils/patch.typ`**.
Locale can adopt it with a small patch. The prototype proves that the same utility makes the
documented locale block example work.

---

## 1. Pitch & mental model

A **theme is a lazy function** that the engine calls late with the master schemas of the
**running** package version. You pass it **uncalled** and customize it with Typst's native
`.with(...)`, using patches from a strict DSL. The two locale axes map one-to-one:

- **lang → style.** The "voice", i.e. how things look: palette, fonts, rules, letterhead, table
  and totals tokens, and the part renderers. A style is a plain _delta dictionary_ over `base-style`,
  the same way `lang.de` is a delta over `base-language`.
- **region → layout.** The regulated regional standard, i.e. where things go: paper, margins,
  address window, info block, reference line, fold and hole marks, stationery, and page furniture.
  A layout is a _function of the final style_ that returns a delta over `base-layout`, the same way
  `region.de(final-lang)` receives the final language. Paper and envelope standards are regional,
  just as tax law is: DIN in DE, SN 010130 in CH, NF Z 11-001 in FR, Letter/#10 in the US.

Presets are named `<style>-<layout>` the way locales are `<lang>-<region>`: `themes.classic-din-5008-a`,
`themes.modern-us-letter-10`, `themes.minimal-a4-digital`. Like `locale.de-ch`, they are
precomputed closures and cost nothing until they are called.

```
                      locale                                  themes
  master schema   base-language   base-region          base-style        base-layout
                        |              |                    |                  |
  shipped delta     lang.de ──► region.de(final-lang)   style.modern ──► layout.din-5008-b(final-style)
                        |              |                    |                  |
  user patches    (strings: …)    (region: …)           (style: …)         (layout: …)
                  locale.custom.*                        themes.custom.*
                        |              |                    |                  |
                        └── Normalized ctx.locale ──┘       └── Normalized ctx.theme ──┘
                                                               (flat groups + meta + source)

  Cascade at runtime (theme):
   running base-style/base-layout  (injected by invoice(), forward compatible)
     <- preset style / layout(final-style)
       <- user patches, left to right   (brand arrays, per-document tweaks; later wins)
         <- themed(..patches)[subtree]   (style only; derived tokens re-derived)
           <- explicit component args    (show-column, qr-code.display, …; data > presentation)

  Rendering:
   CORE frame (not themable)  = set page + absolute zones from LAYOUT + metadata + compliance
     └─ fills each zone by calling a STYLE part (ctx, view) => content
          letterhead | address | info | references | title | table | totals | notes
          bank-details | payment-goal | signature | continuation | footer | page-number
```

Three rules hold the design together:

1. **Data decides what, core decides where, the theme decides how.** The layout schema holds
   geometry. The core frame places zones from that geometry. Style parts fill the zones. Legal
   content, such as notes, the EPC-QR payload, PDF metadata and 0% tax suppression, is produced
   by core and handed to parts. Parts can restyle it but cannot drop it (§5).
2. **One verb, `.with`.** Presets, brands, per-document tweaks and third-party themes are all
   `.with(patch…)` chains over a lazy function. Scoped overrides are the same patches applied to a
   subtree: `#themed(patch…)[…]`.
3. **Master schemas are injected, not imported.** `invoice()` calls
   `theme(themes.base-style, themes.base-layout)`. A theme package built against 0.5.0 is merged,
   resolved and validated against the 0.5.3 schema when a user runs 0.5.3. The prototype verifies
   this across two package versions (§10).

---

## 2. Public API surface

`src/lib.typ` keeps `themes` as a namespace. Its layout mirrors `src/locale/locale.typ`:

```typ
// src/themes/themes.typ   (public facade; mirrors locale.typ)
#import "factory.typ": build-theme
#import "style/style.typ" as style          // ~ locale.lang
#import "layout/layout.typ" as layout       // ~ locale.region
#import "style/base.typ": base-style        // master schema object (defaults, types, hydrate)
#import "layout/base.typ": base-layout
#import "custom.typ"                        // ~ locale.custom  (patch DSL)
#import "footer.typ"                        // predefined footer blocks (issue #18)
#import "scope.typ": themed                 // also re-exported bare from lib.typ (a body verb)
#import "../utils/patch.typ": wrap          // decorate the current renderer

/// Default part renderers, so a replacement can call "super" explicitly.
#let parts = base-style.defaults.parts

// presets: <style>-<layout>
#let classic-din-5008-a = build-theme(style.classic, layout.din-5008-a)   // DEFAULT of invoice()
#let classic-din-5008-b = build-theme(style.classic, layout.din-5008-b)
#let classic-sn-010130-right = build-theme(style.classic, layout.sn-010130-right)
#let classic-us-letter-10 = build-theme(style.classic, layout.us-letter-10)
#let classic-a4-digital   = build-theme(style.classic, layout.a4-digital)
#let modern-din-5008-a    = build-theme(style.modern, layout.din-5008-a)
// … one preset per shipped (style x layout) combination, like the 30 locale presets
```

Shipped axes for 0.5.0:

| `themes.style.*`                                        | purpose                                                                                                |
| ------------------------------------------------------- | ------------------------------------------------------------------------------------------------------ |
| `classic`                                               | today's look, the default. Its tokens are the old wrapper values from `base-theme/line-items.typ:5-39` |
| `modern`                                                | full-bleed brand band, stacked title, header fill in `primary`, tinted totals, boxed bank block        |
| `minimal`                                               | Stripe-like: hairlines, no zebra, large total                                                          |
| (0.5.x) `elegant`, `vibrant`, `luxury`, `informational` | the four hidden variants, re-expressed as token deltas plus at most one `wrap`                         |

| `themes.layout.*`                   | standard                                                                                                |
| ----------------------------------- | ------------------------------------------------------------------------------------------------------- |
| `din-5008-a`, `din-5008-b`          | DIN 5008:2020 forms A and B (the letter-pro numbers, now owned by invoice-pro)                          |
| `sn-010130-right`, `sn-010130-left` | Swiss SN 010130. **The mm values must be verified against the Swiss Post control mask before release.** |
| `nf-z-11-001`                       | French right window, approx. 110 mm / 50 mm (flagged for verification)                                  |
| `uk-c5`                             | A4 in C5, window 20 mm from left, approx. 42 mm from top                                                |
| `us-letter-10`                      | US Letter, #10 window, tri-fold marks at 11in/3                                                         |
| `a4-digital`, `letter-digital`      | no window, no marks, references in the info block                                                       |

### 2.1 Signatures (house doc style)

```typ
/// Builds a lazy theme from a style and a layout. Pass the result UNCALLED to
/// `invoice(theme:)` and customise it with `.with(themes.custom.*)`.
/// Intended for reusable company themes and Typst Universe packages (tier 2).
///
/// -> function
#let build-theme(
  /// Delta over the base style (see `themes.style.*` and `theme/base.md`).
  /// -> dictionary
  style,
  /// Delta over the base layout. Usually `(style) => dictionary`, which
  /// receives the FINAL resolved style (like a region receives the final lang).
  /// -> function | dictionary
  layout,
) = (..patches, base-style, base-layout) => /* Normalized theme dictionary */

/// Applies style patches to a subtree of the invoice body. Tokens derived from a
/// patched token are re-derived inside the subtree. Layout patches are rejected.
/// -> content
#let themed(..patches, body)

/// Decorates whatever renderer currently sits at the patched key.
/// `fn` receives that renderer as first argument (`super`).
/// -> dictionary (a merge marker)
#let wrap(
  /// -> (function, ..any) => any
  fn,
)
```

### 2.2 The patch DSL: `themes.custom`

There is one helper per schema group. The helper name equals the group name, every parameter
defaults to `auto` (meaning untouched), and `none` is kept as a real value (meaning off). The
pipeline discriminator (`style:`/`layout:`) mirrors `strings:`/`region:`. Unlike `locale.custom`,
**every helper returns a one-element array without `return`**, so block form works:

```typ
/// Semantic colours. A function value `(t) => color` is a derivation.
/// -> array
#let palette(primary: auto, accent: auto, text: auto, muted: auto, subtle: auto, rule: auto,
  surface: auto, on-primary: auto, negative: auto, positive: auto, tax-label: auto,
) = emit("style", "palette", (primary: primary, accent: accent, /* … */))
```

| helper                                                                                                                                       | pipeline | keys (see §3)                                                       |
| -------------------------------------------------------------------------------------------------------------------------------------------- | -------- | ------------------------------------------------------------------- |
| `palette`, `fonts`, `rules`, `logo`, `letterhead`, `continuation`, `title`, `table`, `totals`, `notes`, `bank`, `payment`, `footer`, `parts` | `style`  | style groups                                                        |
| `page`, `head`, `window`, `info`, `references`, `body`, `marks`, `stationery`, `furniture`, `reserved`                                       | `layout` | layout groups                                                       |
| `brand(color:, accent:, font:, logo:)`                                                                                                       | both     | convenience macro that emits several patches (the five-minute path) |

Raw dictionaries remain legal and are the target for brand files: `(style: (palette: (primary: red)))`.
Helper names collide with component names (`signature`, `table`, `footer`), so the documented idiom
is the scoped `import themes.custom: *` inside a block, exactly as with locale.

### 2.3 Passing to `invoice()` and why uncalled

```typ
#show: invoice.with(theme: themes.classic-din-5008-a)            // default
#show: invoice.with(theme: themes.modern-din-5008-b.with(acme))  // brand = array of patches
```

`invoice` does `let t = theme(themes.base-style, themes.base-layout)`. This is identical to
`locale(base-language, base-region)` (`invoice.typ:181`). The theme is uncalled for the same
reasons as locale:

- (a) The running version injects its master schema, which gives forward compatibility.
- (b) `.with` accumulates positional patches in call order, so later patches win.
- (c) There is one convention for every preset. The `blank()`-vs-`DIN-5008()` footgun disappears.
  Passing an evaluated dict is rejected with a clear message (§8).

There are **no named options** such as `form: "B"`. That knowledge moves into presets
(`classic-din-5008-b`) or patches (`custom.window(y: 45mm)`). A named argument panics with an
educational message that points to both routes. The locale API has no named options either.

`themes.blank` is gone. "Unstyled with my own page setup" is now a _layout_ concern (see
walkthrough 6 / §6).

---

## 3. Schemas

The two master schemas are **schema objects** `(defaults, types, hydrate)`:

- `defaults` is the documented base dictionary. It is the analogue of `base-language`/`base-region`
  and is the key-by-key content of the `theme/base.md` docs page.
- `types` is a parallel matcher schema. It is used for per-leaf validation with `::` paths, for
  derivation detection (below) and for docs generation.
- `hydrate` holds the group shapes used to re-hydrate optional groups (for example, `info` is
  `none` in DIN A but can be patched back in).

The object shape exists because an older theme package's closure must validate against the
**newer** types. With a bare dict, a new 0.5.1 key would be an "unknown key" to 0.5.0's types. This
problem was found while prototyping (§10, §11).

**Derivations.** A leaf whose value is a function, but whose schema type does not admit functions,
is a derivation `(t) => value`. It is evaluated once, in schema order, against the partially
resolved tree. Examples: `accent: t => t.palette.primary`, `on-primary: t => on-color(t.palette.primary)`.
Renderers (`parts.*`) and builders (`footer.blocks`) admit functions, so for them a function is the
value itself. No explicit marker is needed and there is no ambiguity.

### 3.1 base-style (defaults = the `classic` look)

| group.key                                                                    | type                                   | default                                              | meaning                                                                                      |
| ---------------------------------------------------------------------------- | -------------------------------------- | ---------------------------------------------------- | -------------------------------------------------------------------------------------------- |
| **meta**.name                                                                | str                                    | `"base"`                                             | style name                                                                                   |
| **palette**.primary                                                          | paint                                  | `#1e293b`                                            | brand seed                                                                                   |
| .accent                                                                      | paint                                  | `t => t.palette.primary`                             | second brand colour                                                                          |
| .text / .muted / .subtle                                                     | paint                                  | `black` / `luma(100)` / `luma(80)`                   | text roles                                                                                   |
| .rule                                                                        | paint                                  | `black`                                              | rules                                                                                        |
| .surface                                                                     | paint \| none                          | `#e2e8f0`                                            | zebra / soft fills                                                                           |
| .on-primary                                                                  | paint                                  | `t => on-color(t.palette.primary)`                   | WCAG black/white on primary                                                                  |
| .negative / .positive / .tax-label                                           | paint                                  | `#b22222` / `#333333` / `#475569`                    | discounts, surcharges, tax labels                                                            |
| **fonts**.body                                                               | str \| array                           | `("Liberation Sans",)`                               | family chain                                                                                 |
| .heading                                                                     | str \| array                           | `t => t.fonts.body`                                  | heading family                                                                               |
| .size                                                                        | length                                 | `10pt`                                               | base size                                                                                    |
| .hyphenate / .justify                                                        | bool                                   | `true` / `true`                                      | body paragraphs                                                                              |
| **rules**.thin / .regular / .thick                                           | length                                 | `.5pt` / `1pt` / `2pt`                               | thicknesses (strokes are composed as thickness + paint, so no stroke-dict folding is needed) |
| .paint                                                                       | paint                                  | `t => t.palette.rule`                                | rule paint                                                                                   |
| **logo**.content                                                             | none \| content                        | `none`                                               | `image("x.svg", alt: …)`                                                                     |
| .height / .position                                                          | length / `"left"\|"right"`             | `14mm` / `"left"`                                    |                                                                                              |
| **letterhead**.size                                                          | length                                 | `10pt`                                               | head zone text                                                                               |
| .fill                                                                        | paint \| none                          | `none`                                               | a full-bleed band (the `modern` style sets `t => t.palette.primary`)                         |
| .text                                                                        | paint                                  | on-color(fill) or palette.text                       |                                                                                              |
| .inset-top / .sender-align / .sender-height                                  | length / alignment / auto\|size        | `20mm` / `right` / `5.5cm`                           |                                                                                              |
| .show-subject / .show-extra                                                  | bool                                   | `true` / `true`                                      |                                                                                              |
| **continuation**.size / .text / .rule                                        | length / paint / bool                  | `8pt` / muted / `true`                               | following-page header                                                                        |
| **title**.layout                                                             | `"inline"\|"stacked"`                  | `"inline"`                                           | subject+date arrangement                                                                     |
| .size / .weight / .text                                                      | size / str\|int / paint                | `1.4em` / `"bold"` / palette.text                    |                                                                                              |
| **table**.columns                                                            | array of keys                          | `("quantity","unit-price","tax-rate","total-price")` | order (visibility stays data-driven)                                                         |
| .header-fill / .header-text / .header-weight / .header-size                  |                                        | `none` / text / `"bold"` / `1em`                     |                                                                                              |
| .rule-top / .rule-header / .rule-bottom                                      | length \| none                         | regular / thin / regular                             |                                                                                              |
| .stripe-odd / .stripe-even                                                   | paint \| none                          | `none` / `t => t.palette.surface`                    | replaces `color-row-odd/even` (the doc'd DIN defaults)                                       |
| .row-text / .name-weight / .desc-size / .desc-text                           |                                        | text / `"bold"` / `.85em` / muted                    |                                                                                              |
| .group-fill / .group-text / .group-size / .subtotal-size                     |                                        | `none` / text / `1.05em` / `.85em`                   | group rows are now themable                                                                  |
| .cell-inset                                                                  | sides                                  | `.4em` all sides                                     | stored fully expanded, so a patch folds into it                                              |
| .repeat-header / .tabular                                                    | bool                                   | `true` / `true`                                      | tabular lining figures by default (R4)                                                       |
| **totals**.width / .align / .row-gutter                                      |                                        | `66%` / `right` / `.6em`                             |                                                                                              |
| .rule / .tax-label / .total-size / .total-weight / .total-text / .total-fill |                                        | thick / tax-label / `1.2em` / bold / text / `none`   |                                                                                              |
| **notes**.size / .text                                                       |                                        | `.85em` / muted                                      | legal notes styling                                                                          |
| **bank**.qr-position / .qr-size                                              | `none\|"left"\|"right"` / length       | `"right"` / `25mm`                                   | the core clamps size to ≥ 20 mm                                                              |
| .fill / .stroke / .radius / .inset                                           |                                        | none / none / 0pt / 0 sides                          |                                                                                              |
| **payment**.amount-weight / .amount-text                                     |                                        | bold / text                                          | fixes "bold inside locale strings"                                                           |
| **footer**.blocks                                                            | array of content \| `(ctx) => content` | `()`                                                 | issue #18 columns                                                                            |
| .size / .text / .rule                                                        |                                        | `7.5pt` / muted / `true`                             |                                                                                              |
| **parts**.letterhead … .page-number                                          | `(ctx, view) => content`               | built-in renderers                                   | §5                                                                                           |

### 3.2 base-layout (defaults = DIN 5008 Form A; absolute coordinates from the sheet's top-left)

| group.key                                                                       | type                                       | DIN 5008-A (base)                                                         | meaning                                                  |
| ------------------------------------------------------------------------------- | ------------------------------------------ | ------------------------------------------------------------------------- | -------------------------------------------------------- |
| **meta**.name / .standard                                                       | str / str\|none                            | `"base"` / `"DIN 5008:2020 Form A"`                                       |                                                          |
| **page**.paper                                                                  | str                                        | `"a4"`                                                                    | any Typst paper                                          |
| .margin                                                                         | sides                                      | `(top: 20mm, right: 20mm, bottom: 20mm, left: 25mm)`                      |                                                          |
| **head**.height                                                                 | length                                     | `27mm`                                                                    | first-page letterhead zone (full sheet width)            |
| **window** (optional) .x .y .width .height                                      | length                                     | `20mm, 27mm, 85mm, 45mm`                                                  | address field                                            |
| .return-height / .inset                                                         | length                                     | `17.7mm` / `5mm`                                                          | return line and annotations zone, text indent            |
| .size / .return-size                                                            | length                                     | `10pt` / `7pt`                                                            | **regulated** sizes live in the layout                   |
| **info** (optional) .x .y .width .height                                        | length                                     | `none` (hydrate: `125mm, 32mm, 75mm, 40mm`)                               | DIN information block                                    |
| **references**.placement                                                        | `"line"\|"info"`                           | `"line"`                                                                  | reference line vs info block                             |
| .columns / .gutter / .label-size / .value-size                                  |                                            | `(45.77mm ×3, 25mm)` / `12pt` / `8pt` / `10pt`                            |                                                          |
| **body**.gap                                                                    | length                                     | `12pt`                                                                    | gap below the lowest zone                                |
| **marks**.x / .fold / .fold-length / .hole / .hole-length / .thickness / .paint |                                            | `5mm` / `(87mm, 192mm)` / `2.5mm` / `148.5mm` / `4mm` / `.25pt` / `black` | `none` = off                                             |
| **stationery**.mode                                                             | `"generated"\|"background"\|"pre-printed"` | `"generated"`                                                             | one switch per output channel                            |
| .first / .rest                                                                  | none \| content                            | `none`                                                                    | letterhead art (SVG/PNG/native; **not PDF** under PDF/A) |
| **furniture**.header / .footer                                                  | `none\|"all"\|"first"\|"rest"`             | `"rest"` / `"all"`                                                        | continuation header, footer blocks                       |
| .page-number / .number-single                                                   | position \| none / bool                    | `"footer-right"` / `false`                                                | page numbers from locale strings                         |
| **reserved**.last-bottom                                                        | length                                     | `0mm`                                                                     | brand-immune zone (Swiss QR-bill = `105mm`)              |

### 3.3 The same schema, radically different: US Letter + modern band

```typ
#let us-letter-10(style) = (             // a layout = function of the final style
  meta: (name: "us-letter-10", standard: "US Letter + #10 window envelope"),
  page: (paper: "us-letter", margin: (top: 0.75in, right: 0.75in, bottom: 0.8in, left: 0.875in)),
  head: (height: 1.75in),
  window: (x: 0.875in, y: 2.0in, width: 4.0in, height: 1.125in,
           return-height: 0mm, inset: 0mm, size: 10pt, return-size: 7pt),
  info: (x: 5.25in, y: 2.0in, width: 2.5in, height: 1.4in),   // re-hydrated optional group
  references: (placement: "info"),
  marks: (fold: (11in / 3, 22in / 3), hole: none, paint: luma(160)),
)
#let modern = (                          // a style = plain delta
  meta: (name: "modern"),
  palette: (primary: rgb("#0f766e"), surface: t => t.palette.primary.lighten(90%)),
  letterhead: (fill: t => t.palette.primary, inset-top: 12mm, show-subject: false, sender-height: auto),
  title: (layout: "stacked", size: 2em, text: t => t.palette.primary),
  table: (header-fill: t => t.palette.primary, header-text: t => t.palette.on-primary,
          rule-top: none, rule-header: none, stripe-even: none, cell-inset: (y: .55em)),
  totals: (width: 50%, total-fill: t => t.palette.surface,
           total-text: t => ensure-contrast(t.palette.primary, t.palette.surface)),
  bank: (fill: t => t.palette.surface, inset: 1em, radius: 4pt, qr-position: "left"),
)
#let modern-us-letter-10 = build-theme(modern, us-letter-10)
```

Both compile in the prototype (`out/modern-us-1.png` compared with `out/classic-1.png`). Note that
`cell-inset: (y: .55em)` folds into the sides value and keeps x.

---

## 4. Cascade, precedence & merge semantics

**Layers**, from lowest to highest. Each is a named layer, CSS-`@layer`-style, and documented in
this order:

1. **running `base-style` / `base-layout`**. The master schema is injected by `invoice()`.
2. **preset style delta**, then **`layout(final-style)` delta**. This is the region(lang) order:
   the style is resolved first, so a layout can derive geometry or mark colour from the final style.
3. **user patches in `.with` order**. Brands, company files and per-document tweaks all go here.
   Chained `.with` accumulates arguments, so the later patch wins per key.
4. **`themed(..patches)[…]`**. These are style-only and scoped to a subtree. The scope re-merges into
   the _unresolved_ source and re-resolves, so a scoped `palette(primary: red)` recolours
   everything derived from it.
5. **explicit component arguments** (`line-items(show-column: …)`, `bank-details(qr-code: (display: false))`).
   These are data and per-instance switches, and they win over tokens. Rule: _what_ is shown
   (columns, QR yes/no, totals yes/no) stays on components; _how_ it is shown is a token.

Native Typst rules sit outside this chain. User rules inside the body beat theme set rules for
body content. Rules placed before `#show: invoice` lose. The theme issues only `set text(font, size)`,
`hyphenate` and `justify`, and prefers tokens (prior-art C2).

**`auto` and `none`.** `auto` in a helper means "untouched" (it is stripped by `clean-auto`). `none`
in a value means "off" (no stripe, no fold marks, no window, no QR). Tokens never contain `auto`
after resolution. "Engine decides" is expressed as a derivation, so the Normalized dict is fully
concrete. The only token-level `auto`s are documented Typst-native ones (`sender-height: auto`).

**Merge**. This is the single implementation in `patch.merge(base, patch, path, defaults:)`:

| base value                                          | patch value                                     | result                                                                 |
| --------------------------------------------------- | ----------------------------------------------- | ---------------------------------------------------------------------- |
| dict (group)                                        | dict                                            | recurse, at **any depth** (fixes locale depth-2)                       |
| **sides** dict (keys exactly top/right/bottom/left) | length or partial dict (`x`,`y`,`rest`,`top`,…) | **fold**: only the named sides change (fixes S-25)                     |
| function                                            | `wrap(fn)`                                      | decorated: `(..a) => fn(previous, ..a)`                                |
| `none` (optional group)                             | dict                                            | re-hydrate from the schema's `hydrate`, then merge                     |
| anything                                            | anything else                                   | replace (arrays, scalars, content, functions, `none`)                  |
| —                                                   | unknown key at any depth                        | **panic** with the full `::` path and the allowed keys (fixes I-2/I-3) |

Other rules:

- Patches that are not dictionaries panic.
- Unknown pipelines (for example `colors:`) panic.
- `none` inside a patch list (from `if false { … }` in a block) is ignored.
- Strokes are never merged. They are composed at render time as `thickness + palette/rules.paint`.

**Derivation / aliasing.** The whole palette follows one seed: `accent`, `on-primary`, `rules.paint`,
`table.stripe-even` (= `surface`), `table.header-text` and so on are derivations. Patching only
`palette(primary: maroon)` re-derives `table.header-fill` in `modern` (verified by assertion 3 in
`tests/dsl.typ`). Helpers `on-color`, `contrast`, `ensure-contrast` are exported for use in
derivations. Their WCAG maths was verified in prior-art C7.

**When and what it costs.** Resolution happens **once per compile**, in `invoice()`, before
`weave`. Steps:

1. collect patches;
2. fold style;
3. pre-validate literal leaves;
4. resolve derivations in schema order;
5. validate;
6. fold layout;
7. resolve and validate layout;
8. normalize.

The theme lives under **one ctx key** (`theme`), which the loom cost model (loom §3.6) favours
over flat keys. Its size is about 200 leaves plus about 15 functions. `themed` adds one resolution
per scope per pass (2 passes). Measured on a 2-page, 30-item invoice: **~550 ms vs ~490 ms**
baseline on the 0.4.2 DIN theme. The new version also renders an every-page footer, a continuation
header and localized page numbers (§10). A demo with two `themed` scopes compiles in ~440 ms.

---

## 5. Renderer / part contract

**Uniform signature: `(ctx, view) => content`.** There is no third `body` argument. The five 0.4
shapes and the callback zoo collapse into one convention. Parts read **tokens only from `ctx.theme`**
and **data only from `view`**. The `view` is built by core per call, with fresh values. Parts are
draw-only and cannot emit signals, so they cannot affect ZUGFeRD.

| part           | called by                                        | view (frozen fields in bold)                                                                                                                  |
| -------------- | ------------------------------------------------ | --------------------------------------------------------------------------------------------------------------------------------------------- |
| `letterhead`   | core frame, page 1, head zone (inside `context`) | **sender** (normalized party), **subject**, **logo**, **margin**, **width**, **height**                                                       |
| `address`      | core frame, window rect                          | **recipient**, **return-line** (content\|none), **annotations**, **window** (geometry)                                                        |
| `info`         | core frame, info rect                            | **entries** `array<(label, value)>`, **geometry**                                                                                             |
| `references`   | core frame, after zones                          | **entries**, **geometry**                                                                                                                     |
| `title`        | core frame                                       | **subject**, **place**, **date** `(value, display)`                                                                                           |
| `table`        | line-items component                             | **entries** (items, group-header/footer, each optionally with **theme-scope**), **layout-information**                                        |
| `totals`       | line-items component                             | **net/gross/due/prepaid** `(value: decimal, display: str)`, **taxes** (0% already removed), **tax-mode**                                      |
| `notes`        | line-items component                             | **notes** `array<content>` (legally required, decided by core)                                                                                |
| `bank-details` | bank-details component                           | **holder**, **bank**, **iban** `(value, display)`, **bic**, **reference**, **amount** `(value, display)`, **qr**: `none \| (size) => content` |
| `payment-goal` | payment-goal component                           | **amount** `(value, display)`, **sentence**: `(sum-content) => content` from locale                                                           |
| `signature`    | signature component                              | **closing**, **name**, **signature**                                                                                                          |
| `continuation` | core frame, header, page ≥ 2                     | **page**, **pages**, **subject**, **sender-name**                                                                                             |
| `footer`       | core frame, footer                               | **columns** `array<content>` (already evaluated by core), **page**, **pages**                                                                 |
| `page-number`  | core frame, footer                               | **page**, **pages**, **label** (locale `document.page(n, total)`)                                                                             |

**View hygiene** (addresses S-18 and S-20):

- Every formatted scalar is a record `(value, display)`. Themes get raw decimals (they can colour
  negatives) _and_ locale formatting.
- Names are consistent (`surcharges` plural everywhere, `formatted-`).
- Content-vs-str is fixed per field.
- No part ever reads `ctx.global`. Views are assembled from the component's own measure and, for
  page parts, from root's draw ctx, which is fresh.
- The one second-order value, `bank.payment-amount: auto`, is resolved by **root** in measure. It
  used to be one pass stale in child slots.

**Wrap vs replace.**

```typ
parts(signature: (ctx, view) => [...])                         // replace (eject)
parts(totals: themes.wrap((super, ctx, view) =>                // wrap: decorate what is there,
  block(stroke: (left: 3pt + ctx.theme.palette.primary), super(ctx, view))))
parts(title: (ctx, view) => themes.parts.title(ctx, view) + v(1em))  // call the default explicitly
```

`wrap` composes against **the renderer present at merge time** (preset → brand → user). A third-party
theme's wrap therefore decorates the _running_ version's default, not a captured old copy. This is
verified in `tests/thirdparty.typ`.

**Stability tiers (declared in `theme/base.md`).**

- _Frozen in 0.5.0_:
  - `build-theme`, `themed`, `wrap` signatures;
  - the calling convention;
  - all `themes.custom` helper names;
  - the group and key names of `palette, fonts, rules, logo, letterhead, title, totals, notes, bank, payment, footer`, and all layout groups;
  - part names and the `(ctx, view)` signature;
  - the bold view fields above;
  - the Normalized `meta` (`style`, `layout`, `standard`, `contract: 1`).
- _Experimental (may change in 0.5.x, documented as such)_:
  - `table` tokens beyond stripes/header/rules;
  - the table view's `entries` shape for groups and modifiers;
  - `theme-scope` per entry;
  - `reserved` zones;
  - `continuation` tokens.
- _Internal_: `ctx.theme.source`, the prototype bridges.

**Where compliance lives: core, never a part.**

| obligation                                                             | owner                                                                                                           | how a theme cannot lose it                                                                                                                     |
| ---------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------- |
| PDF metadata (`set document` title/author/date/keywords incl. ZUGFeRD) | `root.draw` before the frame                                                                                    | parts never see it. Every theme now passes PDF/UA-1's title check (verified `ua-1`, `a-3a,ua-1`)                                               |
| `text.lang`/`region`                                                   | root; `build-locale` now returns `lang` (fixes S-17)                                                            | page labels "Page 2 of 2" / "Seite 2 von 2" verified                                                                                           |
| ZUGFeRD XML                                                            | `root.draw` `pdf.attach` (unchanged, reads no theme)                                                            | verified `factur-x.xml` + XMP keywords under a-3b with the `modern` theme                                                                      |
| legal notes (§19 UStG, exemption grounds, markers)                     | line-items measure (proto: `notes-logic.typ`) → `view.notes`                                                    | core composes `table → totals → notes` in fixed order and **panics if `parts.notes` returns nothing while notes exist** (verified message, §8) |
| 0% tax suppression (#39)                                               | core filters `view.taxes`                                                                                       | parts only receive what must be listed                                                                                                         |
| EPC-QR payload (EUR only, amount ≥ 0.10, reference vs text, IBAN)      | core builds `view.qr` as a closure                                                                              | forces black on white and min 20 mm; the part only chooses placement/size                                                                      |
| address in the envelope window                                         | core frame places parts at layout coordinates                                                                   | a style cannot move it; only a layout patch can, and it is validated                                                                           |
| Swiss QR-bill / regulated zones                                        | `reserved.last-bottom` + a core `regulated(body)` scope that resets font to Liberation Sans, black, fixed sizes | the brand cannot reach inside (0.5.x, with the QR-bill component)                                                                              |

---

## 6. Page frame & arbitrary formats

**invoice-pro owns the frame; letter-pro is dropped.** It was about 120 lines to re-own, and the
prototype's `frame.typ` is about 150 lines including furniture. The frame:

- issues `set page(paper, margin, background, header, footer)` at top level (fixes S1);
- places the first-page zones with `place(top+left, dx: x - margin.left, dy: y - margin.top)` from
  absolute layout coordinates;
- reserves `v(max(bottom of zones) - margin.top + body.gap)`;
- then renders references (line placement), the title and the body.

Any format is therefore _data_: rectangles on page 1, plus furniture rules per page.

| need                            | how                                                                                                                                                                                                                                      |
| ------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| paper                           | `page.paper` (any Typst paper, including `"us-letter"`)                                                                                                                                                                                  |
| margins                         | `page.margin` sides value; `custom.page(margin: (bottom: 35mm))` folds                                                                                                                                                                   |
| window                          | `window` rect + `return-height` + regulated sizes; `none` = digital                                                                                                                                                                      |
| info block                      | `info` rect; `references.placement: "info"` moves references into it                                                                                                                                                                     |
| marks                           | `marks.fold` array / `hole` / `paint` (`none` = off); drawn in `background` together with stationery                                                                                                                                     |
| first vs following pages        | `head` zone and letterhead only on page 1; `furniture.header: "rest"` continuation header; `furniture.footer: "all"\|"first"\|"rest"`                                                                                                    |
| letterhead paper                | `stationery.mode`: `"generated"` (parts render letterhead and footer), `"background"` (`first`/`rest` art drawn as page background, generated letterhead/footer suppressed), `"pre-printed"` (nothing in those zones, geometry kept)     |
| page numbering                  | `furniture.page-number` position; label from the new locale key `document.page: (n, total) => content`; fully localized                                                                                                                  |
| multi-column legal footer (#18) | `footer(blocks: (themes.footer.sender, themes.footer.tax-ids, themes.footer.bank, [free content with #info.*]))`. Builders are `(ctx) => content` like `references`; core evaluates them outside `context`, so `info.*` motifs stay live |
| reserved zones                  | `reserved.last-bottom`: core adds `v` space / a page before the regulated block; font/colour reset scope                                                                                                                                 |

**A completely new format without forking** is one function plus one call:

```typ
#import "@preview/invoice-pro:0.5.0": *
#let nf-z-11-001(style) = (
  meta: (name: "nf-z-11-001", standard: "NF Z 11-001"),
  head: (height: 40mm),
  window: (x: 110mm, y: 50mm, width: 85mm, height: 40mm, return-height: 8mm),
  info: (x: 25mm, y: 50mm, width: 70mm, height: 40mm),
  references: (placement: "info"),
  marks: (fold: (99mm, 198mm), hole: none, paint: style.palette.rule),
)
#show: invoice.with(theme: themes.build-theme(themes.style.classic, nf-z-11-001))
```

**Third-party theme packages on Typst Universe.** A package contains _data and plain functions
only_: a style dict, a layout function, and optional `wrap`s. It does **not** emit motifs. The loom
key is version-bound (`<invoice-pro:X.Y.Z>`), so `info.*` from the package's own invoice-pro import
would be silently ignored (loom t10). Footer blocks are builders `(ctx) => content` that read `ctx`
directly. User-supplied content blocks come from the user's own (running) import, and core
evaluates them with the running `eval-content`. The factory closure from the package's version runs
against the **running** schema objects, so new keys arrive with their defaults, and validation and
derivation use the new `types`. This is verified with a local `acme-theme:0.1.0` package built
against 0.5.0 and used from 0.5.1, which adds `palette.link`.

---

## 7. Walkthroughs

**P1: Freelancer, five minutes, digital only.**

```typ
#show: invoice.with(
  theme: themes.classic-a4-digital.with(themes.custom.brand(
    color: rgb("#0f766e"), font: ("Inter", "Liberation Sans"),
    logo: image("logo.svg", alt: "Studio Lina Berg"),
  )),
  locale: locale.de-de, tax-exempt-small-biz: true, /* … */
)
```

**P2: GmbH with pre-printed paper, digital letterhead and ZUGFeRD, one switch.**

```typ
#let mode = sys.inputs.at("output", default: "pdf")        // print | pdf | einvoice
#let acme = {                                               // brand.typ - an array of patches
  import themes.custom: *
  brand(color: rgb("#003a70"), accent: rgb("#e2001a"), font: ("Source Sans 3", "Liberation Sans"),
        logo: image("acme.svg", alt: "ACME Maschinenbau GmbH"))
  footer(blocks: (themes.footer.sender, themes.footer.tax-ids, themes.footer.bank,
                  [Amtsgericht Stuttgart HRB 12345 · GF: Dr. E. Muster, M. Beispiel]))
}
#show: invoice.with(
  theme: themes.classic-din-5008-b.with(acme, {
    import themes.custom: *
    stationery(
      mode: if mode == "print" { "pre-printed" } else if mode == "pdf" { "background" } else { "generated" },
      first: image("letterhead-p1.svg"), rest: image("letterhead-p2.svg"),   // SVG: PDF/A-safe
    )
    marks(fold: if mode == "print" { (105mm, 210mm) } else { none }, hole: none)
  }),
  zugferd: if mode == "einvoice" { "en16931" } else { none }, /* … */
)
```

(The three modes are verified in `tests/stationery.typ`.)

**P3: Swiss SME, right window, QR-bill.**

```typ
#show: invoice.with(
  locale: locale.de-ch,
  theme: themes.classic-sn-010130-right.with({
    import themes.custom: *
    palette(primary: rgb("#7a1f2b")); fonts(body: ("Source Serif 4", "Libertinus Serif"))
    reserved(last-bottom: 105mm)                  // core keeps footer/page number out of it
  }),
)
#line-items[ … ]
#qr-bill(account: "CH44 3199 9123 0008 8901 2")   // (0.5.x) rendered in the core regulated scope
```

**P4: Agency with white-label brands in TOML.**

```typ
#let job = json(sys.inputs.job)
#let entity = toml("brands/" + job.brand + ".toml")
#let brand-patch = themes.custom.from-data(entity.theme, logo: image("brands/" + entity.theme.logo))
// from-data: parses "10.5pt"/"#0b3d91" strings with the regex parser (no eval), returns a patch
// array; unknown TOML keys fail with `theme::style::palette::primry` paths
#show: invoice.with(theme: themes.modern-din-5008-a.with(brand-patch), sender: entity.sender, ..job.header)
```

**P5: SaaS batch pipeline.**

```typ
// theme.typ - built once, imported everywhere (immutable value)
#let company = themes.minimal-a4-digital.with(
  themes.custom.from-tokens(json("design/brand.tokens.json")),   // DTCG adapter (0.5.x, COULD)
)
// invoice.typ
#show: invoice.with(theme: company, locale: locale.at(d.locale), zugferd: "en16931", ..d.header)
// typst compile --pdf-standard a-3a,ua-1 --font-path fonts --input data=… invoice.typ
```

**P6: Design studio, Stripe-like on DIN B paper.**

```typ
#show: invoice.with(theme: themes.modern-din-5008-b.with({
  import themes.custom: *
  palette(primary: rgb("#111827"), accent: rgb("#6366f1"), surface: none)
  fonts(body: "Inter", heading: "Fraunces")
  totals(total-size: 1.8em, total-text: t => t.palette.accent)
  parts(payment-goal: (ctx, view) => block(fill: ctx.theme.palette.accent.lighten(90%), inset: 1em,
    (view.sentence)(text(weight: "bold", view.amount.display))))
}))
```

**P7: Accessibility-bound supplier.**

```typ
#show: invoice.with(theme: themes.classic-din-5008-a.with(
  themes.custom.brand(color: rgb("#00843d"), logo: image("sw.svg", alt: "Stadtwerke Musterstadt")),
  themes.custom.marks(fold: none, hole: none),
))
// core metadata + lang fix -> passes ua-1; theme `contrast` check (see §8) is opt-in strict
```

**P8: US subsidiary, same brand.**

```typ
#import "corporate.typ": acme                       // the SAME patch array as P2
#show: invoice.with(locale: locale.en-us, theme: themes.classic-us-letter-10.with(acme,
  themes.custom.footer(blocks: ([Remit to: ACME Inc., PO Box 1, Austin TX], [billing\@acme.com]))))
```

**(9) Third-party theme package author** (verified as `pkgs/local/acme-theme/0.1.0/lib.typ`):

```typ
#import "@preview/invoice-pro:0.5.0": themes
#let acme-style = (meta: (name: "acme"), palette: (primary: rgb("#7c2d12")),
  letterhead: (fill: t => t.palette.primary, show-subject: false, sender-height: auto),
  parts: (totals: themes.wrap((super, ctx, view) => block(stroke: (left: 3pt + ctx.theme.palette.primary), super(ctx, view)))))
#let acme-layout(style) = (meta: (name: "acme-din-b"), head: (height: 45mm), window: (y: 45mm),
  marks: (fold: (105mm, 210mm), paint: style.palette.primary))
#let acme = themes.build-theme(acme-style, acme-layout)
#let acme-letter = themes.build-theme(acme-style, themes.layout.us-letter-10)
// consumer: #show: invoice.with(theme: acme.with(themes.custom.fonts(body: "Inter")))
```

**(10) Scoped style for one highlighted group** (verified in `tests/demo.typ`):

```typ
#line-items[
  #item([Konstruktion], price: 950)
  #themed({
    import themes.custom: *
    table(stripe-odd: rgb("#fef3c7"), stripe-even: rgb("#fde68a"), group-fill: rgb("#f59e0b"), group-text: white)
  })[
    #group([Option: Express-Fertigung])[ #item([Expresszuschlag], price: 180) ]
  ]
]
#themed(themes.custom.bank(fill: rgb("#ecfeff"), inset: 8pt))[ #bank-details(…) ]
```

Items and groups are data motifs with no draw pass. Their measure copies the scope's resolved
row-level tokens (`theme-scope: (table, palette)`) into the entry, and the table part prefers them.

---

## 8. Validation & error messages

These are the verified outputs of `tests/errors/*.typ`, in house style:

| input                                                     | message                                                                                                                                                                                             |
| --------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `custom.palette(primry: red)`                             | `unexpected argument: primry` (native, from the enumerated helper)                                                                                                                                  |
| raw `(style: (palette: (primry: red)))`                   | ``unknown key `theme::style::palette::primry`. Allowed keys: primary, accent, text, muted, subtle, rule, surface, on-primary, negative, positive, tax-label``                                       |
| unknown group `pallete`                                   | ``unknown key `theme::style::pallete`. Allowed keys: meta, palette, fonts, …``                                                                                                                      |
| `palette(primary: "#ff0000")`                             | ``variable `theme::style::palette::primary`("#ff0000") must be of color \| gradient \| tiling`` (checked _before_ derivations run)                                                                  |
| derivation returns the wrong type `stripe-even: t => 3pt` | ``variable `theme::style::table::stripe-even`(3pt) must be of none \| color \| gradient \| tiling``                                                                                                 |
| `cell-inset: (z: 1em)`                                    | ``unknown key `theme::style::table::cell-inset::z`. Allowed keys: top, right, bottom, left, x, y, rest``                                                                                            |
| `.with(form: "B")`                                        | ``theme: unexpected named argument(s) `form`. Themes take no named options - use patches, e.g. `.with(themes.custom.window(y: 45mm))`, or pick another preset (e.g. `themes.classic-din-5008-b`).`` |
| `.with("B")`                                              | `theme: patch #1 must be a dictionary produced by a `custom.\*` helper, found string ("B")`                                                                                                         |
| `(colors: …)`                                             | ``theme: unknown patch pipeline `colors`. Allowed pipelines: style, layout``                                                                                                                        |
| theme passed called / as a dict                           | ``variable `invoice::theme` must be of function (a lazy theme such as `themes.classic-din-5008-a`, passed UNCALLED), found dictionary``                                                             |
| `parts(notes: (..) => none)` with legal notes             | `theme::parts::notes returned nothing, but 3 legally required note(s) exist (e.g. tax exemption grounds). A notes renderer may restyle notes, never drop them.`                                     |
| `themed(custom.window(..))`                               | `themed: layout patches (page, window, marks, ...) cannot be scoped - page geometry is document-global. …`                                                                                          |

**When checks run.** All checks run once, in `invoice()`, before weave. `themed` runs the same
checks at scope time. Helpers give IDE completion and native arity errors. The merge and validator
give `::` paths.

**Coverage.** `tests/dsl.typ` calls every helper with every key of its schema group. This fails if a
helper misses a key (the locale drift I-6).

**Low contrast.** Typst has no warning API. The default derivations use `on-color` and
`ensure-contrast`, so a brand colour cannot produce unreadable header text. An opt-in check,
`custom.accessibility(min-contrast: 4.5)`, panics with
`theme::style::table::header-text on header-fill has contrast 3.53:1 (< 4.5:1); use t => on-color(t.table.header-fill)`.
Opt-in is needed because brand guidelines sometimes knowingly accept 3:1 for large text.

**Assets under PDF/A.** Typst's own error for PDF images is late and cryptic. `stationery.first/rest`
and `logo.content` are content, so the frame cannot inspect the file type. The design therefore:

- documents SVG/PNG;
- adds a guard when `zugferd != none`. If an image's `source` field ends in `.pdf`, core panics with
  `theme::layout::stationery::first: PDF images cannot be embedded under PDF/A-3 (ZUGFeRD); convert the letterhead to SVG`.
  `image` content exposes `source` on 0.14.

`cmyk` paints are rejected by the paint validator when `zugferd != none`.

---

## 9. Internals sketch

```
src/utils/patch.typ          clean-auto, emit (1-element arrays), wrap, merge (strict, deep, sides fold,
                             re-hydrate), fold, collect (pipelines), get/set-path   <- shared with locale
src/themes/
  themes.typ                 public facade (presets, style, layout, custom, footer, parts, themed, wrap)
  factory.typ                build-theme, resolve-axis (pre-validate -> derive -> validate), normalize
  schema.typ                 type vocabulary (paint, size, sides, opt), validator with :: paths,
                             derivation resolver, on-color / contrast / ensure-contrast
  style/base.typ             style-defaults + style-types -> base-style = (defaults, types, hydrate)
  style/style.typ            classic, modern, minimal (+ elegant/vibrant/luxury/informational in 0.5.x)
  layout/base.typ            layout-defaults (= DIN 5008 A) + layout-types -> base-layout
  layout/layout.typ          din-5008-a/b, sn-010130-*, nf-z-11-001, uk-c5, us-letter-10, *-digital
  custom.typ                 patch DSL (one helper per group) + brand macro (+ from-data 0.5.x)
  frame.typ                  CORE page frame (set page, zones, furniture, title)
  scope.typ                  themed motif (deep merge into ctx.theme.source, re-resolve)
  footer.typ                 footer block builders
  parts/{page,line-items,payment}.typ   default part renderers
src/components/*             build v0.5 views in measure; draw calls ctx.theme.parts.<part>
src/components/root.typ      set document + text lang; pdf.attach; frame(ctx, body)
```

**Plumbing.**

1. `invoice()` validates `theme` as a function and calls
   `theme(themes.base-style, themes.base-layout)`. It checks that the result is a Normalized
   theme, then puts it under **one ctx key `theme`**.
2. There are no per-component `ensure` fallbacks for slots, because the theme is complete by
   construction. The three 0.4 fallback policies disappear.
3. Built-in parts read `ctx.theme.<group>.<key>`. Defaults are defined **once**, in `style-defaults`
   / `layout-defaults`. The duplicated defaults in up to five places, with diverging values
   (theme-internals §3.4), collapse to one.
4. `themed` is an unnamed compute motif. It keeps `sys.path`, so `assert-direct-parent` guards of
   items still pass (verified with items inside `themed` inside `line-items`). It costs one nesting
   level, which is well within loom's ~19-level budget.
5. The theme is never re-resolved per node, only per `themed` scope.
6. Large collections are never injected into ctx. `theme-scope` on entries is about 30 leaves and
   only for scoped entries.

**0.14 compatibility.** The prototype uses only 0.14-era features: `std.table`, `tiling`,
`array.filter/map`, `context`, `place`, `counter(page).final()`. It avoids `dictionary.map/filter`
and `path()`. The coverage test uses `dictionary(module)`. **It has not been run on 0.14.0.**
Milestone M0 adds a 0.14.0 CI job. **I do not recommend bumping the minimum compiler** for this design.

**Nice-to-have loom fixes** (the design works without them):

- export `matcher.display` (removes invoice-pro's copy);
- an `optional()` matcher plus a path-reporting `match` (would replace `schema.validate`);
- `ensure` distinguishing missing from `none`;
- a deep `apply` prebuilt (would make `themed` a one-liner);
- fix the labelled-container crash so users can label wrappers as style hooks;
- the observer typo;
- a version-independent motif key option (would let theme packages ship motifs).

---

## 10. Feasibility evidence

Prototype root: `<session>/proto-locale-symmetry/`.
It was compiled with typst 0.15.1 using `typst compile --root . <file> out/<name>-{p}.png`
(add `--package-path pkgs` for the third-party test).

New or changed files:

- `src/utils/patch.typ`
- `src/themes/{factory,schema,custom,frame,scope,bridge,footer,notes-logic,themes}.typ`
- `src/themes/style/{base,style}.typ`, `src/themes/layout/{base,layout}.typ`, `src/themes/parts/{page,line-items,payment}.typ`
- modified: `src/invoice.typ`, `src/components/{root,line-items,bank-details,payment-goal,signature,item,group}.typ`, `src/logic/tree.typ`, `src/locale/factory.typ` (lang fix), `src/locale/lang/{base,de}.typ` (page label), `src/lib.typ` (`themed`)

About 2,200 inserted lines, of which roughly 700 are the new theming core and parts.

| test                                                                                                                   | verified                                                                                                                                                                                                                                                                                                                                                                                     |
| ---------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `tests/demo.typ` × `--input variant=classic \| classic-brand \| modern-us \| minimal-digital \| swiss` → `out/*-1.png` | **One invoice body, five formats**: DIN A (classic), DIN B + brand patch array (logo, 4-column legal footer), **US Letter #10 + modern band** (radically different geometry and look), A4 digital minimal (window-less, references in the info block), Swiss right window. Same data, only the `theme:` value differs                                                                        |
| same file                                                                                                              | **Scoped overrides**: `themed(table(...))` around a `group` restyles exactly that group's header, rows and subtotal (row-level tokens travel with data motifs). `themed(bank(...))` restyles one bank block                                                                                                                                                                                  |
| `tests/multipage.typ` (+ `--input lang=de`)                                                                            | continuation header on page 2, footer blocks on every page, "Page 2 of 2" (en-de) / "Seite 2 von 2" (de-de), so **the S-17 lang bug is fixed**; `marks(hole: none)` removes the hole mark                                                                                                                                                                                                    |
| `tests/stationery.typ` × `output=print\|pdf\|einvoice`                                                                 | one-switch stationery: pre-printed (no letterhead), background art first/rest, generated                                                                                                                                                                                                                                                                                                     |
| `tests/dsl.typ` (11 assertion groups, prints "ALL DSL ASSERTIONS PASSED")                                              | block DSL keeps both patches; `none` survives; seed derivations; chaining later-wins with component-token re-derivation; sides fold; depth-N merge; optional-group re-hydration; `wrap`; layout receives the final style; helper/schema coverage; brand macro + `if false` blocks; **the same `patch.typ` fixes the locale block example and depth-2 loss** (`de.units.hour` keeps `plural`) |
| `tests/errors/e1…e12.typ`                                                                                              | all 12 messages in §8 (after one fix: literal pre-validation before derivations; see below)                                                                                                                                                                                                                                                                                                  |
| `tests/thirdparty.typ` + `pkgs/local/{invoice-pro/0.5.0,invoice-pro/0.5.1,acme-theme/0.1.0}`                           | a theme package built against 0.5.0 used from 0.5.1: the new 0.5.1 key `palette.link` is injected and derived (assertion), `wrap` decorates the running version's totals, marks take the brand colour through `layout(style)`                                                                                                                                                                |
| `--pdf-standard a-3b` + `--input zugferd=basic`                                                                        | `factur-x.xml` attached; XMP title "Rechnung 2026-0815", keywords "Invoice, ZUGFeRD, Factur-X" come from core                                                                                                                                                                                                                                                                                |
| `--pdf-standard ua-1`, `a-3a,ua-1`                                                                                     | the modern and minimal themes compile clean                                                                                                                                                                                                                                                                                                                                                  |
| timing                                                                                                                 | 2-page, 30-item invoice: 549–552 ms (new) vs 476–524 ms (0.4.2 DIN baseline, `baseline/mp.typ`)                                                                                                                                                                                                                                                                                              |

**What failed or needed fixing during prototyping** (all reflected in the design):

1. Wrong-typed literals crashed inside a derivation (`on-color("#ff0000")`) before validation
   could report them. Fix: validate literal leaves before resolving derivations.
2. The first factory imported its own types. That would make a newer schema's keys "unknown" to
   older theme packages. Fix: master schema _objects_ `(defaults, types, hydrate)` are injected.
3. `invoice::theme` given an evaluated dict printed the whole dict via `types.require`. It was
   replaced with a short, targeted message.
4. My initial assertion expected white on Typst `red`. WCAG correctly picks black (5.3:1 vs 3.9:1).
5. `zugferd: "en16931"` with region de panicked for missing BT-10/BT-49 recipient data. This is a
   pre-existing data rule, unrelated to theming, so `basic` was used for the attachment check.

**Not verified:**

- typst 0.14.0;
- the legacy line-items renderer behind the new tokens (M1 migration adapter, which keeps
  pixel-identical refs; not built);
- `from-data` / DTCG adapters;
- the QR-bill regulated scope;
- `accessibility(min-contrast)`;
- the PDF-image guard.

**Visual quirks** in the prototype:

- The totals block wrapped by `acme-theme` loses right alignment (the wrap replaced the aligned box
  with a full-width block; an authoring issue, not a mechanism issue).
- The `a4-digital` sender block slightly overflows its 38 mm head zone. This is the same
  overflow-by-design as today's 5.5 cm block (S-29), and the token `letterhead.sender-height` exists
  to fix it.
- The modern band's white logo placeholder is a stand-in.

---

## 11. Trade-offs, risks & rejected alternatives

**Weaknesses.**

- **Preset explosion.** `<style>-<layout>` scales multiplicatively (4 × 9 = 36 names). Locale lives
  with 30. They are free closures, but the docs table grows. Mitigation: document
  `build-theme(style, layout)` prominently as the combinatorial escape. An alternative is to keep
  presets for the default style only.
- **Two parallel schema trees** (defaults + types). The coverage test keeps them honest, but it is
  maintenance. It is still less than today's five default copies.
- **Hand-enumerated helpers** repeat keys a third time (for IDE completion and native errors). This
  is the house style, and it is guarded by the coverage test.
- **Derivation order is positional**: a derivation may only reference earlier keys. It is simple
  and deterministic, but a user patch that references a later key gets a function instead of a
  value and a type error.
- **Named options are gone.** `themes.DIN-5008(form: "B")` has no one-to-one successor call; it
  maps to `themes.classic-din-5008-b`. That is fine given decision 1, but it is a real migration
  (template, README, about 20 visual tests).
- **The core frame is not replaceable.** A layout that is not "absolute zones on page 1 + furniture"
  (for example, a two-column sidebar invoice with the address in the sidebar) must be expressed
  with zones plus `body.gap` tricks, or wait for an experimental `parts.page` escape hatch. I
  deliberately did not make the frame a part, because that is exactly how 0.4 lost metadata and
  window guarantees.
- **Arrangement of table → totals → notes is fixed** (compliance). "Totals beside notes" is not
  possible in 0.5.0.
- **Scoped overrides inside `line-items` affect row-level tokens only.** Column sets or totals per
  subtree are not supported. Page geometry cannot be scoped.
- Swiss, French and UK coordinates are not authoritative. **They are flagged, not guessed silently.**

**Deliberately left out.**

- No locale → layout auto-inference (R11). It would need a third injected argument (the evaluated
  locale). This is a candidate for 0.6: `layout` functions receiving `(style, locale:)`.
- No elembic, no valkyrie (prior-art D15/D16).
- No theme-supplied component default args (MUI `defaultProps`).
- No CMYK.
- No carry-over subtotals.

**Rejected alternatives.**

- A single "tokens" pipeline without layout: this loses the region symmetry and the
  regulated-geometry separation.
- Keeping `blank`: its role is taken by `*-digital` layouts plus `parts` replacement.
- Explicit `derive()` markers: noisier. The type schema already disambiguates.
- A theme-owned `document` slot: this is the root cause of lost metadata and lost window alignment
  in 0.4.
- A flat `ctx.theme.style.*` / `ctx.theme.*` asymmetric reshape copied from locale's
  `strings`-vs-flattened-region: I flatten both axes, because consumers should not care which axis
  a group came from.

**Mark experimental in 0.5.0:** `table` tokens beyond the stripe/header/rule/group set,
`theme-scope`, `reserved`, `continuation`, `themes.parts.*` as call targets, `from-data`.

---

## 12. Implementation roadmap (solo maintainer; each milestone shippable)

| M                           | scope                                                                                                                                                                                                                                                                                                                                                                                 | tests                                                                                                                                                                                                                         |
| --------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **M0** (0.5.0-dev)          | `utils/patch.typ` + unit tests. **Adopt it in locale**: rewrite the `locale.custom` helpers to `emit`, use `patch.fold` in `build-locale`, return `lang` (S-17). This is independently shippable as a locale bugfix release                                                                                                                                                           | `tests/unit/patch` (merge/sides/wrap/collect/errors); `tests/docs/locale-customize` finally registered; en/fr page-label visual tests                                                                                         |
| **M1**                      | `build-theme`, schema objects, `themes.custom`, `classic` style + `din-5008-a/b`, core `frame.typ` (letter-pro removed), core metadata. Parts initially **adapt the existing renderers**: the `table/totals/notes` parts call the current generic `render-line-items` with token-mapped params, so the ~20 DIN visual refs stay pixel-identical or close. Move `set document` to root | re-run all refs, update one by one (fix-tests skill); `tests/integration/theme-dsl` (the `dsl.typ` assertions); `tests/errors/theme-*` compile-fail tests; CI adds `--pdf-standard a-3b` and `a-3a,ua-1` for built-in presets |
| **M2**                      | Views v0.5: `(value, display)` records, `notes`/`qr` computed in core, uniform `(ctx, view)` parts, bank payment-amount resolved in root. Migrate the ~35 `themes.blank` test call sites to `classic-a4-digital` plus `parts` hooks, or to a `test-theme` fixture analogous to `test-locale`                                                                                          | `tests/unit/views` (data-test on view shapes); issue-39/41 rewritten against `parts.totals` + `wrap`                                                                                                                          |
| **M3**                      | `themed` motif + entry `theme-scope`; furniture (continuation header, footer blocks, page-number positions), `themes.footer.*` → **closes #18**                                                                                                                                                                                                                                       | integration `footer-every-page`, `themed-group`, `themed-bank` visual tests                                                                                                                                                   |
| **M4**                      | Layout catalogue: `us-letter-10`, `a4/letter-digital`, `uk-c5`; `sn-010130-*` and `nf-z-11-001` **only after verifying mm against official masks**; stationery modes                                                                                                                                                                                                                  | one visual test per layout (window rectangle overlay in debug mode); `stationery-{print,pdf,einvoice}`                                                                                                                        |
| **M5**                      | Styles `modern`, `minimal`; port elegant/vibrant/luxury/informational as deltas; `brand` macro; contrast helpers + opt-in `accessibility` check; PDF-image/CMYK guards                                                                                                                                                                                                                | visual tests per style × default layout; guard compile-fail tests                                                                                                                                                             |
| **M6** (0.5.x)              | `from-data` brand loader (regex length parser), DTCG adapter, QR-bill regulated scope with `reserved`                                                                                                                                                                                                                                                                                 | unit tests for the parser; QR-bill visual test                                                                                                                                                                                |
| **Docs** (alongside each M) | `api-reference/theme/{index,custom,base}.md`, the same trio as locale: _use a preset_ / _customise with `themes.custom` and author with `build-theme`_ / _base schema tables generated from `types`_; "publish your own theme package" page mirroring "Europe East"; every snippet registered in DOCUMENTATION.md + TESTING.md with a `tests/docs/api-theme-*` test                   | docs registry test per snippet                                                                                                                                                                                                |

The locale-first ordering (M0) is deliberate. It ships the shared utility where users benefit
immediately, and it proves the patch semantics before the theme API is locked on top of them.
