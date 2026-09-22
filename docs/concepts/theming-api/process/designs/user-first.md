# invoice-pro v0.5.0 Theming API: "user-first"

**Lens:** start from the code people actually write and work back to the smallest model that supports it.
**Prototype:** `scratchpad/proto-user-first/`. 1,202 lines in `src/theme/`, 10 rendering tests and 8 error tests, all compiled with typst 0.15.1 (section 10).

---

## 1. Pitch & mental model

A theme is **one value that you pass uncalled**, exactly like a locale: `theme: theme.classic`. You customize it with **flat, named knobs**. Knobs are one word each, chain-safe and spreadable from a data file, and every rung of the customization ladder is one more knob in the same call:

```
theme.classic                                                    rung 0  pick a style preset
theme.classic.with(logo: .., color: .., font: ..)                rung 1  brand (3 knobs)
            .with(layout: "din-5008-b", medium: "digital",       rung 2  structure switches
                  footer: theme.blocks.legal, stripes: none)
            .with(stationery: (first: .., rest: ..))              rung 3  letterhead paper
            .with(payment: it => block(.., (it.default)()))       rung 4  wrap / re-parameterize / replace a part
            .with(layout: my-format-dict, letterhead: it => ..)   rung 5  a completely new format
```

There is **one vocabulary**: 29 knobs. The same words work as builder arguments, in positional patch dicts, in TOML/JSON/YAML files, in `kinds: (reminder: ..)` and in `#restyle(..)[..]`. So nobody has to learn a second API at the next rung. Behind the knobs sits a small model with **four groups**, and knobs are sugar for paths inside it:

```
                       knobs (29 words, one vocabulary)
   logo color accent font heading-font | layout medium marks stationery stripes |
   letterhead address info title table totals notes payment bank signature header footer page-number |
   brand tokens page parts kinds | assets
                                     │ normalize (each knob -> one model path)
                                     ▼
  ┌──────────────┬───────────────────────┬──────────────────────────┬────────────────────────────┐
  │ brand        │ tokens                │ page (geometry)          │ parts                      │
  │ seeds, data  │ semantic roles,       │ paper, margins, zones    │ one entry per visible unit │
  │ logo, color, │ derived from brand    │ (letterhead/address/     │ opts + render:             │
  │ accent, font │ (palette, sizes,      │ info rects), marks,      │ auto|none|fn|content       │
  │              │ strokes, numbers)     │ reserved zones           │                            │
  └──────┬───────┴──────────┬────────────┴────────────┬─────────────┴──────────────┬─────────────┘
         │ axis 1: WHO      │ derived               │ axis 2: WHERE (layout)     │ axis 3: HOW (style preset)
         └──────────────────┴──────────┬────────────┴────────────────────────────┘
                                       ▼
       resolved once before weave -> ctx.theme (ONE ctx key) -> frame + part renderers (draw-only)
                                       │
            COMPLIANCE CORE (never in a theme): PDF metadata, text.lang, ZUGFeRD XML,
            legal notes decision, zero-tax rule, EPC payload, refusal of none for legal parts
```

The three axes are independent: **brand** (who), **layout** (where things sit on which paper), and **style preset** (how it looks: `classic | modern | minimal | plain`). `medium` (`print | digital | pre-printed`) is a _mode switch_ on top of them. DIN 5008 is just `layout: "din-5008-a"`, one data preset among `din-5008-b`, `us-letter-10`, `a4`, `sn-010130-right`, or your own dict.

---

## 2. Public API surface

### 2.1 Exports (`src/lib.typ`)

```typst
#import "theme/theme.typ"                 // namespace == parameter name (like locale:/locale.)
#import "theme/resolve.typ": restyle      // a body verb, so a bare function (like apply, item)
```

`themes` (plural) is removed. Per the maintainer's decision, no backwards compatibility is kept.

| Export                                                          | Kind                                      | Purpose                                                                                                                                        |
| --------------------------------------------------------------- | ----------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------- |
| `theme.classic`, `theme.modern`, `theme.minimal`, `theme.plain` | theme builders (functions, pass uncalled) | style presets; all share **one signature**                                                                                                     |
| `theme.layouts`                                                 | dictionary of geometry dicts              | `din-5008-a`, `din-5008-b`, `sn-010130-right`_, `nf-z-11-001`_, `uk-c5`_, `us-letter-10`_, `a4`, `us-letter` (\*experimental geometry)         |
| `theme.blocks`                                                  | module                                    | footer/header building blocks: `sender`, `contact`, `register`, `tax-ids`, `bank`, `page-number`, `continuation`, and the preset array `legal` |
| `theme.build`                                                   | function                                  | tier 2: turn a knob dict into a new preset (used by agencies and theme packages)                                                               |
| `theme.base`                                                    | dictionary                                | the documented master schema (defaults defined once)                                                                                           |
| `theme.replace`                                                 | function                                  | makes a dict-valued patch replace instead of deep-merge                                                                                        |
| `theme.palette`                                                 | module                                    | `contrast`, `on`, `ensure-contrast`, `tint`: WCAG helpers for authors                                                                          |
| `restyle`                                                       | motif                                     | scoped override of a subtree; same knobs                                                                                                       |
| later: `theme.specimen`, `theme.immune`                         | helper, scope                             | brand QA sheet; brand-immune zone for regulated parts                                                                                          |

### 2.2 The builder signature (identical for every preset; house doc style)

```typst
/// A theme preset. Pass it uncalled (`theme: theme.classic`) and customize it
/// with `.with(..)`. Calling it without `env` is equivalent to `.with(..)`.
///
/// -> function
#let classic(
  /// Knob dictionaries applied in order before the named knobs, for example
  /// from data files (`toml("brand.toml")`) or shared company settings.
  /// Every key must be a knob name. Dict values deep-merge.
  /// -> dictionary
  ..patches,
  /// Page geometry: a layout preset name or a geometry dictionary.
  /// `auto` picks the preset from the locale region (de/at -> "din-5008-a", us -> "us-letter-10").
  /// -> auto | str | dictionary
  layout: auto,
  /// Output mode. "pre-printed" hides letterhead, stationery and footer columns;
  /// "digital" disables fold/hole marks. A mode wins over styling of what it hides.
  /// -> auto | "print" | "digital" | "pre-printed"
  medium: auto,
  /// Company logo. Always give `alt` (PDF/UA). A string is a path that needs `assets`.
  /// -> auto | none | content | str
  logo: auto,
  /// The one brand color. The whole palette (stripe, rules, on-color,
  /// AA-safe text variant) is derived from it. Hex strings are accepted.
  /// -> auto | color | str
  color: auto,
  /// Secondary brand color. Defaults to `color`.
  /// -> auto | color | str
  accent: auto,
  /// Body font family or fallback chain.
  /// -> auto | str | array
  font: auto,
  /// Heading font. Defaults to `font`.
  /// -> auto | str | array
  heading-font: auto,
  /// Fold/hole marks from the layout. `true`/`false` or options.
  /// -> auto | bool | dictionary
  marks: auto,
  /// Letterhead paper (Briefpapier) behind the page: one content for all pages
  /// or `(first: .., rest: ..)`. Use SVG/PNG for PDF/A (ZUGFeRD).
  /// -> auto | none | content | str | dictionary
  stationery: auto,
  /// Row fill of the line-items table (#33): off, one color, or (odd, even).
  /// -> auto | none | color | array
  stripes: auto,
  /// One knob per visible part. Values:
  ///  - dictionary: options of the built-in renderer (see schema)
  ///  - function `it => content`: wrap (`(it.default)()`) or replace the part
  ///  - content: static replacement (`#info.*` motifs are resolved)
  ///  - none: hide (refused for legally required parts)
  ///  - array (header/footer only): columns of blocks/content
  /// -> auto | none | dictionary | function | content | array
  letterhead: auto, address: auto, info: auto, title: auto, table: auto,
  totals: auto, notes: auto, payment: auto, bank: auto, signature: auto,
  header: auto, footer: auto, page-number: auto,
  /// Model groups for data files and power users (deep-merged patches).
  /// -> auto | dictionary
  brand: auto, tokens: auto, page: auto, parts: auto,
  /// Per document kind knob patches, e.g. `(reminder: (color: red))`.
  /// -> auto | dictionary
  kinds: auto,
  /// Resolves path strings from data files, relative to YOUR file:
  /// `assets: p => image(p, alt: "ACME")`.
  /// -> auto | function
  assets: auto,
  /// Injected by `invoice()`; never set by users.
  /// -> none | dictionary
  env: none,
) = ...
```

### 2.3 Passing it to `invoice()`

```typst
/// The theme: a preset such as `theme.classic`, optionally customized with
/// `.with(..)`, or a dictionary of knobs applied to `theme.classic`.
/// -> function | dictionary
theme: theme.classic,
```

- `theme: theme.modern` is the uncalled preset.
- `theme: theme.modern.with(color: teal)` is canonical, as in locale.
- `theme: theme.modern(color: teal)` works too and means the same (see below).
- `theme: (color: teal, stripes: none)` or `theme: toml("brand.toml")` is a knob dict on `theme.classic`.

`invoice()` evaluates it as `theme(env: (kind: "invoice", region, lang, zugferd))`. It asserts that the result is a resolved theme and otherwise names the mistake in plain words.

**Why uncalled plus `.with`, with calling allowed?**
(a) The locale API uses the same convention, so users already know it.
(b) `invoice` injects `env` (document kind, region for `layout: auto`, zugferd for guards) late, the way locale receives its bases.
(c) The builder is **idempotent without `env`**: when called by a user, it returns `self.with(..args)`. So the old footgun where `themes.DIN-5008` was called in one place and `themes.blank` passed uncalled in another (a silently unstyled page) **cannot exist any more**: both spellings produce the same value (verified in `f5-custom-format.typ`).

**Why flat knobs instead of `brand: (color:, font:)`?** Typst's `.with` replaces a dict-valued named argument wholesale. I verified that `f.with(brand: (color: 1, font: 2)).with(brand: (color: 3))` leaves `(brand: (color: 3))`, so the font is lost. A company theme that the document then retunes (`acme.with(color: red)`) is _the_ 80% layering case. Flat scalar knobs make it safe, and they are shorter to type. Dict-valued knobs (`table:`, `tokens:`, …) replace only an earlier _named_ knob of the same name; positional dicts always deep-merge (see §4).

---

## 3. Schemas

### 3.1 Base schema (`theme.base`, defined once in `src/theme/base.typ`)

| Path                                                                                           | Type                                                                              | Default                               | Meaning                                                           |
| ---------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------- | ------------------------------------- | ----------------------------------------------------------------- |
| `brand.logo`                                                                                   | none \| content                                                                   | `none`                                | logo (a string is resolved via `assets`)                          |
| `brand.color`                                                                                  | auto \| color                                                                     | `auto`                                | seed; `auto` = neutral (today's black/slate look)                 |
| `brand.accent`                                                                                 | auto \| color                                                                     | `auto`                                | secondary; `auto` = `color`                                       |
| `brand.font`                                                                                   | str \| array                                                                      | `"Liberation Sans"`                   | body font chain                                                   |
| `brand.heading-font`                                                                           | auto \| str \| array                                                              | `auto`                                | `auto` = `font`                                                   |
| `tokens.colors.text / muted / subtle`                                                          | color                                                                             | `black / luma(100) / luma(80)`        | text roles (today's literals)                                     |
| `tokens.colors.primary`                                                                        | auto \| color                                                                     | `auto`                                | `brand.color` or black                                            |
| `tokens.colors.primary-text`                                                                   | auto \| color                                                                     | `auto`                                | primary darkened to ≥ 4.5:1 on white (not in `strict` mode)       |
| `tokens.colors.on-primary`                                                                     | auto \| color                                                                     | `auto`                                | black/white chosen by contrast                                    |
| `tokens.colors.accent`                                                                         | auto \| color                                                                     | `auto`                                | `brand.accent` or primary                                         |
| `tokens.colors.heading`                                                                        | color \| role-name                                                                | `"text"`                              | alias to another role (TOML-friendly)                             |
| `tokens.colors.rule`                                                                           | color \| role-name                                                                | `black`                               | table and totals rules                                            |
| `tokens.colors.stripe`                                                                         | auto \| color                                                                     | `auto`                                | `#e2e8f0` (neutral) or OKLCH tint of seed at L = 95%              |
| `tokens.colors.negative / positive / tax-label / marks`                                        | color                                                                             | `#b22222 / #333333 / #475569 / black` | today's literals                                                  |
| `tokens.sizes.body / small / large`                                                            | length/rel                                                                        | `11pt / .85em / 1.2em`                |                                                                   |
| `tokens.sizes.letterhead / address / return-line / footer / reference-label / reference-value` | length                                                                            | `10 / 10 / 7 / 7.5 / 8 / 10 pt`       | letter-pro's literals, now tokens                                 |
| `tokens.strokes.thin / regular / thick / marks`                                                | length                                                                            | `.5pt / 1pt / 2pt / .25pt`            | paint comes from colour roles                                     |
| `tokens.numbers`                                                                               | "proportional" \| "tabular"                                                       | `"proportional"`                      | tabular figures in the table (modern/minimal: tabular)            |
| `tokens.contrast`                                                                              | "auto" \| "strict" \| "off"                                                       | `"auto"`                              | fix silently / panic below AA / do nothing                        |
| `page.name`                                                                                    | str                                                                               | –                                     | layout id                                                         |
| `page.size`                                                                                    | (length, length)                                                                  | `(210mm, 297mm)`                      | any paper                                                         |
| `page.margin`                                                                                  | (left, right, top, bottom)                                                        | `25/20/20/20mm`                       | body margins (all pages)                                          |
| `page.letterhead`                                                                              | rect `(x, y, width, height)`                                                      | `(0,0,auto,27mm)`                     | page-1 top zone; `width: auto` = sheet width                      |
| `page.address`                                                                                 | none \| rect + `return-height`, `indent`                                          | `none`                                | envelope window; `none` = recipient in the flow                   |
| `page.info`                                                                                    | none \| rect                                                                      | `none`                                | information block (used when `parts.info.position: "block"`)      |
| `page.body-top`                                                                                | auto \| length                                                                    | `auto`                                | y where page-1 flow starts; `auto` = below the window + 12pt      |
| `page.marks`                                                                                   | `(enabled, fold: array, hole, x, fold-length, hole-length)`                       | –                                     | fold/hole marks                                                   |
| `page.reserved`                                                                                | array of `(page: "last", side: bottom, height, immune: true)`                     | `()`                                  | regulated brand-immune zones (Swiss QR-bill)                      |
| `parts.stationery`                                                                             | `(render, first, rest)`                                                           | none                                  | Briefpapier                                                       |
| `parts.letterhead`                                                                             | `(render, style: "split"\|"band"\|"minimal", logo-height, extras)`                | split                                 |                                                                   |
| `parts.address`                                                                                | `(render, return-line, annotations)`                                              |                                       | **compliance part**                                               |
| `parts.info`                                                                                   | `(render, position: "line"\|"block")`                                             | line                                  | reference line vs information block                               |
| `parts.title`                                                                                  | `(render, style: "classic"\|"large", date)`                                       | classic                               |                                                                   |
| `parts.table`                                                                                  | `(render, row-fill, header: "rule"\|"filled", rule, column-order)`                |                                       | **compliance part**                                               |
| `parts.totals`                                                                                 | `(render, width, emphasis: "bold"\|"accent")`                                     | `66%`, bold                           | **compliance part** (#39/#41 knobs go here, e.g. `net: "always"`) |
| `parts.notes`                                                                                  | `(render)`                                                                        |                                       | **compliance part** (legal statements)                            |
| `parts.payment / bank / signature`                                                             | `(render, ..)`; bank: `qr, qr-size`                                               |                                       |                                                                   |
| `parts.header`                                                                                 | `(render, continuation: bool)`                                                    | false                                 | pages ≥ 2                                                         |
| `parts.footer`                                                                                 | `(render, columns: array, height: auto, rule)`                                    | `()`                                  | #18                                                               |
| `parts.page-number`                                                                            | `(render, position: none\|"footer-right"\|"footer-center"\|"header-right", from)` | footer-right, 1                       | wording from the locale                                           |
| `kinds`                                                                                        | dict kind → knob dict                                                             | `(:)`                                 | quote, credit-note, reminder, delivery-note …                     |

### 3.2 DIN 5008 A (`theme.layouts.din-5008-a`, pure data)

```typst
(name: "din-5008-a", size: (210mm, 297mm),
 margin: (left: 25mm, right: 20mm, top: 20mm, bottom: 20mm),
 letterhead: (x: 0mm, y: 0mm, width: auto, height: 27mm),
 address: (x: 20mm, y: 27mm, width: 85mm, height: 45mm, return-height: 17.7mm, indent: 5mm),
 info: (x: 125mm, y: 32mm, width: 75mm, height: 40mm),
 body-top: auto,
 marks: (fold: (87mm, 192mm), hole: 148.5mm, x: 5mm))
```

`din-5008-b` differs only in `letterhead.height: 45mm`, `address.y: 45mm`, `info.y: 50mm` and `fold: (105mm, 210mm)`.

### 3.3 Radically different layouts, same schema

US Letter with a #10 window and tri-fold (rendered in `f2-us-modern`):

```typst
(name: "us-letter-10", size: (8.5in, 11in),
 margin: (left: 0.875in, right: 0.75in, top: 0.6in, bottom: 0.75in),
 letterhead: (x: 0in, y: 0in, width: auto, height: 1.55in),
 address: (x: 0.875in, y: 2.0in, width: 4in, height: 1.125in, return-height: 0in, indent: 0in),
 info: (x: 5.25in, y: 1.85in, width: 2.5in, height: 1.4in),
 body-top: 3.55in,
 marks: (fold: (3.667in, 7.333in), hole: none, x: 0.2in))
```

An A5 landscape "compact" sheet with no window and no marks, defined in a user file with no fork (rendered in `f5-custom-format`):

```typst
(name: "a5-compact", size: (210mm, 148mm),
 margin: (left: 14mm, right: 14mm, top: 12mm, bottom: 14mm),
 letterhead: (x: 0mm, y: 0mm, width: auto, height: 24mm),
 address: (x: 14mm, y: 26mm, width: 90mm, height: 24mm, return-height: 0mm, indent: 0mm),
 info: (x: 130mm, y: 26mm, width: 66mm, height: 24mm),
 body-top: 54mm, marks: (fold: (), hole: none))
```

Swiss QR-bill (future) adds `reserved: ((page: "last", side: bottom, height: 105mm, immune: true),)`, which any layout may carry.

### 3.4 Style presets are only knob dicts

```typst
#let classic = build("classic", (:))                         // today's look
#let modern  = build("modern", (
  medium: "digital", letterhead: (style: "band", logo-height: 12mm), info: (position: "block"),
  title: (style: "large", date: false), stripes: none, table: (rule: "primary"),
  totals: (emphasis: "accent", width: 55%), header: (continuation: true), footer: blocks.legal,
  tokens: (colors: (heading: "primary-text", rule: "primary"), numbers: "tabular"),
))
#let minimal = build("minimal", (..))                        // hairlines, no fills
#let plain   = build("plain", (medium: "digital", letterhead: none, page-number: (position: none)))
```

No preset has code paths of its own. The four hidden line-item variants (elegant, vibrant, luxury, informational) become further knob dicts once `table` gains `header: "pill"` and `label-case: "upper"` options.

---

## 4. Cascade, precedence & merge semantics

### 4.1 Layers (verified order in `resolve.typ:resolve`)

```
1 package base             theme.base (every key, neutral values)
2 layout preset            page <- layouts[layout]   (layout: auto -> region map)
3 style preset             knob dict baked into theme.classic/modern/...
4 medium bundle            e.g. digital -> marks.enabled: false
5 positional patches       .with(toml(..), (table: (..)), ..)  in order
6 named knobs              .with(color: .., footer: ..)
7 kind patch               kinds.at(env.kind)          (reminder, credit-note, ...)
8 assets                   string paths -> content via the user's loader
9 validate                 unknown keys, types, compliance refusals
10 derive                  palette from seed, aliases, heading-font, contrast
   ── ctx.theme (one key) ──
11 restyle(..)[..]         re-resolves 1-10 with an extra patch appended to layer 6, per subtree
12 component arguments     bank-details(qr-code:), line-items(show-column:) win per instance
```

`medium` is also a **mode**: whatever it hides (`pre-printed` hides letterhead, stationery and footer columns) stays hidden even if a later layer styles that part. I found this by testing: a user's `letterhead: it => ..` renderer otherwise re-showed the letterhead on pre-printed paper.

Native Typst rules sit outside the chain, as the prior-art report found: rules inside the body win for body content, and rules before `#show: invoice` lose to the frame.

### 4.2 `auto` and `none`

- `auto` means **not set**. A layer with `auto` leaves the lower layer untouched (`merge-deep` skips it), and a token left at `auto` after all layers is **derived**. The same meaning applies in files: an absent key is `auto`.
- `none` means **off**: no logo, no stripes (`stripes: none`), no marks, part hidden. It is a real value and survives the merge. Known loom trap avoided: resolution never uses `ensure-deep`, which treats `none` as missing.
- For the four compliance parts, `none` is refused with an explanation (§8).

### 4.3 Merge depth

`merge-deep` is **deep for dicts everywhere**, so `page: (margin: (bottom: 30mm))` keeps the other three margins. It fixes the locale depth-2 bug and the inset bug where `(y: .8em)` dropped x in the elegant preset. **Arrays, functions, content and scalars replace** (`column-order`, `footer` columns, `fold` positions). To replace a dict wholesale, use `theme.replace((..))`. Typst's own `.with` semantics apply to _named_ knobs across chained `.with` calls: a later `.with(table: (..))` replaces an earlier `.with(table: (..))`. To layer dicts, pass them positionally (`.with((table: (..)))`) or put them in a file. This is the one rule users must learn about precedence, and flat scalar knobs make it rarely matter.

### 4.4 Derivation from one seed (`derive`, verified)

`primary = color`; `accent = accent || primary`; `on-primary = on(primary)` (WCAG); `primary-text = ensure-contrast(primary, white, 4.5)`; `stripe = oklch-tint(color, 95%)` (neutral `#e2e8f0` when no color is set, so the default look is preserved); role aliases such as `rule: "primary"` resolve against the final roles. For `color: #0f766e` I verified `stripe = #d6f8f1`-ish (rendered in f1) and, for the reminder kind with `#b91c1c`, `stripe = #ffe6e2` (f6).

### 4.5 When resolution happens and what it costs

Resolution runs **once, before `weave`**, in `invoice()`. `restyle` re-runs it once per scope and per loom pass (scope runs twice with `max-passes: 2`). The result sits under a single ctx key `theme`, about 150 leaves plus closures. That is well inside the loom report's cost model, and nothing is re-resolved per component. Measured with the same 12-item, 2-page body on typst 0.15.1: legacy DIN theme **664–1056 ms**; new `classic` **776–804 ms**; `minimal` plus TOML brand plus two `restyle` scopes **673–870 ms**. That is within noise (3 runs each).

---

## 5. Renderer / part contract

### 5.1 Themable units

`stationery, letterhead, address, info, title, table, totals, notes, payment, bank, signature, header, footer, page-number`. The names are roles, not "invoice" words, so a quote, credit note or reminder uses the same parts. Items, groups, bundles and modifiers are data motifs. They are drawn by `table`, and they are reached through `table` options or through `restyle` scope capture (§5.6).

### 5.2 One signature for every part: `it => content`

The single-argument signature follows Typst's own show-rule idiom. `it` is the **view**:

| Field                                  | Stability                              | Content                                                                   |
| -------------------------------------- | -------------------------------------- | ------------------------------------------------------------------------- |
| `it.part`                              | frozen                                 | part name                                                                 |
| `it.opts`                              | frozen                                 | resolved options of this part (schema §3.1)                               |
| `it.tokens`, `it.brand`, `it.geometry` | frozen                                 | resolved groups (`geometry` = `page`)                                     |
| `it.data`                              | frozen per part (after the M4 cleanup) | normalized data (below)                                                   |
| `it.locale`                            | frozen                                 | `strings`, `format`, `lang`, `currency`                                   |
| `it.page`                              | frozen (furniture only)                | `(current, total)`; `none` outside header/footer                          |
| `it.body`                              | frozen (table only)                    | stray content inside `line-items[..]`                                     |
| `it.default`                           | frozen                                 | `(..opts-overrides) => content`: the built-in renderer bound to this `it` |
| `it.ctx`                               | **unstable** escape hatch              | the raw loom ctx                                                          |

Every rung is a small step (all verified in `f4-rungs`):

```typst
payment: (emphasis: "accent"),                                     // options
letterhead: it => (it.default)(extras: false, logo-height: 11mm),  // re-parameterize the default
payment: it => block(fill: it.tokens.colors.stripe, inset: 8pt, (it.default)()),   // wrap
signature: it => [#it.locale.strings.signature.closing \ #strong(it.data.name)],   // replace
```

A function's output and content values are passed through `eval-content`, so `#info.*` motifs inside user parts resolve (the maintainer's `eval-content` intent).

### 5.3 The data contract (fixing the research findings)

Frozen shapes are **records with both raw and formatted values** and consistent names:

- `Money = (value: decimal, text: str)`, `Rate = (value: ratio, text: str)`, `DateV = (value: datetime, text: str)`, `Text = content` for anything user-provided.
- Plurals everywhere: `discounts`, `surcharges`, `prepayments`. The `formated-*` typo goes away; `has-*` flags go away (use `x != none` / `x.len() > 0`).
- `table.data = (entries: array<item|group-header|group-footer>, columns: (key: (visible: bool, forced: bool)), totals: (net, gross, due, prepaid: Money), taxes: array<(rate: Rate, category, amount: Money, marker, grounds)>, notes: array<(marker, text)>, tax-mode, row: (fill) per entry)`. `columns.forced` distinguishes "the user forced it" from "auto", which is research finding 5.
- `bank.data = (holder, bank, iban (formatted & raw), bic, reference, qr: content|none, amount: Money)`. `qr` is **built by the core** (EPC rules, EUR only, ≥ 0.10, black on white, size clamped to ≥ 2cm).
- `payment.data = (days, date: DateV|none, total: Money)`; `signature.data = (name, signature)`.
- Furniture and page-1 parts get `(sender, recipient, bank, subject, invoice-nr, date, references)`. `references` is **always** normalized (root computes it once), which removes the stale-ctx and raw-function problems.

In the prototype the table still receives today's view (legacy shape). The cleanup is milestone M4, and until then `table.data` is marked experimental.

### 5.4 Stability tiers in v0.5.0

- **Frozen:** knob names and meanings; `auto`/`none` semantics; merge rules; base-schema group and key names in §3.1; part names; the `it` fields except `ctx`; the block convention `(it, ..opts) => content`; the zone/rect schema; `theme.build(name, knobs)`.
- **Experimental** (documented as such): `it.ctx`; `table.data` until M4; the visual appearance of `modern`/`minimal`; non-DIN geometries; the region→layout map; `kinds`; `reserved` zones.
- **Internal:** the component adapters (`document`, `line-items`, … keys in the resolved dict), the generic line-items engine and its 50 parameters. They are never exported, so they may be refactored freely.

### 5.5 Where compliance-critical output lives

| Output                                                                   | Owner                                                                  | How a theme cannot lose it                                                                                          |
| ------------------------------------------------------------------------ | ---------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------- |
| PDF metadata (title, author, date, keywords incl. ZUGFeRD)               | `root.draw` (moved out of the theme; verified in prototype)            | set before `theme.document` runs, for every theme incl. `plain` (`plain` passes `ua-1`, old `blank` did not)        |
| `text.lang`/region                                                       | root, plus a fix for `build-locale` lacking `lang` (prototype)         | en-de now prints "Page 1 of 2" (f2)                                                                                 |
| ZUGFeRD XML                                                              | root (unchanged)                                                       | themes are draw-only                                                                                                |
| Legal notes (§19 UStG, exemption grounds, markers), zero-tax suppression | **measure** of line-items → `table.data.notes` / filtered `taxes` (M4) | `notes: none` refused; a custom `notes` function whose output is `none`/`[]` while `data.notes` is non-empty panics |
| EPC-QR payload                                                           | core builds `bank.data.qr` (M4)                                        | a theme only places it and cannot recolor it                                                                        |
| Recipient address, line items, totals                                    | parts `address`, `table`, `totals`                                     | `none` refused (verified message, §8)                                                                               |
| Page-number wording                                                      | locale strings (`strings.document.page`)                               | the theme chooses position only                                                                                     |

### 5.6 Scoped styling of drawn-by-parent data (`restyle` capture)

`restyle` re-resolves the theme for its subtree. Data components inside it (items) **capture the scope's row style into their signal** (`row-fill`), and the `table` renderer applies it to exactly their rows. Verified: a highlighted group in `f3` has yellow rows while the rest of the table keeps the minimal style. Parts drawn by components (payment, bank, signature) just read the scoped `ctx.theme` (f3: red payment amount, teal totals outside the scope).

---

## 6. Page frame & arbitrary formats

**invoice-pro owns the frame.** letter-pro is dropped. `frame.typ` is 84 lines and does the following:

1. `set page(width, height, margin, header: context .., footer: context .., background: context ..)`. The bottom margin grows to at least 30mm automatically when footer columns exist.
2. Background: stationery (`first` on page 1, `rest` after, sized to the sheet), then marks from `page.marks` with `tokens.strokes.marks + tokens.colors.marks` (themable, e.g. light grey).
3. Page 1: a fixed-height block up to `body-top` in which `letterhead`, `address` and (if `position: "block"`) `info` are **placed absolutely from sheet coordinates**. So a new format means new numbers, not new code. Then come the reference line (if `position: "line"`), the title, and the body. Everything is emitted in logical reading order, as PDF/UA requires.
4. Header and footer run on **every page** with `it.page = (current, total)` from `context`. `header.continuation: true` gives a compact line on pages ≥ 2 (sender · subject · "Page x of y"). The footer page number is then suppressed to avoid duplicates, a bug I found and fixed.

**Multi-column legal footer (#18).** It works like `references`: an array mixing predefined blocks and your own content.

```typst
footer: theme.blocks.legal                                   // (sender, register, tax-ids, bank)
footer: (theme.blocks.sender, theme.blocks.register.with(title: "HRB"), [Geschäftsführung: Erika Muster])
footer: (columns: theme.blocks.legal, rule: false, height: 28mm)
```

Blocks read structured sender keys (`register`, `management`, `capital`, `phone`, `email`, `web`, `bank: (name, iban, bic)`) and render nothing when data is missing. The convention is **one convention for all blocks**: `(it, ..options) => content`, customized with `.with`. This fixes references' called-in-arrays/uncalled-in-dicts split (I-9).

**Localized page numbering.** The prototype has a small lang map; v0.5 adds `strings.document.page: (current, total) => content` to the locale schema.

**Pre-printed paper.** `medium: "pre-printed"` keeps the geometry and the window but suppresses letterhead, stationery and footer columns, while page numbers stay (verified with `--input output=print` in f4).

**Reserved, brand-immune zones.** A layout lists `reserved` rects. The frame keeps footer and body out of a reserved zone on the page it names. A regulated component (future `qr-bill`) renders inside `theme.immune[..]`, which resets font to Liberation Sans, fill to black and size to 10pt, ignoring tokens. The EPC-QR is always black on white with a size floor. Of this paragraph only the EPC colouring was implemented.

**A completely new format without forking:** pass a geometry dict as `layout:` (it is deep-merged onto the base, so partial dicts are fine), and optionally a part function. `f5` does A5 landscape with a custom letterhead in about 20 lines of user code.

**A third-party theme package on Typst Universe.** loom's motif key is version-bound (`<invoice-pro:X.Y.Z>`), so a package must **not** import invoice-pro to produce values. It ships **pure data plus plain functions**:

```typst
// @preview/invoice-theme-fjord:0.1.0  (no invoice-pro import at all)
#let layout = (name: "fjord-a4", size: (210mm, 297mm), margin: (..), letterhead: (..), address: (..), info: none, body-top: 80mm, marks: (fold: ()))
#let knobs = (
  layout: layout,
  letterhead: it => block(width: it.geometry.size.at(0), height: it.geometry.letterhead.height,
    fill: gradient.linear(it.tokens.colors.primary, it.tokens.colors.accent), ..),
  table: (rule: "accent"), stripes: none,
  footer: (it => it.data.sender.name, it => it.data.sender.at("web", default: none)),
)
```

```typst
// user document
#import "@preview/invoice-theme-fjord:0.1.0" as fjord
#show: invoice.with(theme: theme.build("fjord", fjord.knobs).with(color: rgb("#1d4ed8"), logo: ..))
// or simply: theme: theme.minimal.with(fjord.knobs, color: ..)
```

Knobs are validated against the _running_ base schema, which gives the same forward-compatibility promise as `build-locale`. Parts use `it`, never `info.*` motifs from a foreign version. If a theme package wants motifs, the _user_ passes content (`footer: [#info.iban]`), which is woven with the running key.

---

## 7. Walkthroughs

**P1 Freelancer, digital only, 5 minutes**

```typst
#show: invoice.with(
  theme: theme.classic.with(logo: image("logo.svg", alt: "Studio Lina Berg"), color: rgb("#0f766e"), font: "Inter", medium: "digital"),
  locale: locale.de-de, tax-exempt-small-biz: true, sender: (..), recipient: (..), invoice-nr: "2026-014",
)
```

**P2 GmbH: pre-printed paper plus a digital twin plus ZUGFeRD, § 35a footer**

```typst
// acme.typ (shared)
#let acme = theme.classic.with(logo: image("acme.svg", alt: "ACME Maschinenbau GmbH"),
  color: rgb("#003a70"), accent: rgb("#e2001a"), font: ("Source Sans 3", "Liberation Sans"),
  footer: theme.blocks.legal, page-number: (position: "footer-right", from: 2))
// invoice.typ
#let mode = sys.inputs.at("output", default: "pdf")        // print | pdf | einvoice
#show: invoice.with(
  theme: acme.with(layout: "din-5008-b",
    medium: if mode == "print" { "pre-printed" } else { "digital" },
    stationery: if mode == "pdf" { (first: image("lh-1.svg"), rest: image("lh-2.svg")) } else { none }),
  zugferd: if mode == "einvoice" { "en16931" },
  sender: (name: "ACME Maschinenbau GmbH", .., register: "Amtsgericht Stuttgart HRB 12345",
           management: ("Dr. Erika Muster", "Max Beispiel"), vat-id: "DE123456789"),
)
```

**P3 Swiss SME, right window, QR-bill**

```typst
#show: invoice.with(locale: locale.de-ch,
  theme: theme.classic.with(layout: "sn-010130-right", logo: image("logo.svg", alt: "Treuhand Aare AG"),
    color: rgb("#7a1f2b"), font: ("Source Serif 4", "Libertinus Serif")))
#line-items[..]
#qr-bill(..)   // future component: renders in theme.immune inside the layout's reserved bottom zone
```

**P4 Agency, 12 white-label brands in TOML**

```typst
// brands/nordlicht.toml:  [brand] logo="nordlicht.svg" color="#0b3d91" font=["IBM Plex Sans","Liberation Sans"]
//                         [sender] ..   [bank] ..
#let job = json(sys.inputs.job)
#let e = toml("brands/" + job.brand + ".toml")
#show: invoice.with(
  theme: theme.modern.with(..e.brand, assets: p => image("brands/" + p, alt: e.sender.name)),
  sender: e.sender, ..job.header)
```

A typo (`colr = ..`) gives: _theme: unknown option `colr` in `patch #1`. Did you mean `color`?_ (verified).

**P5 SaaS batch in CI**

```typst
// theme.typ, built once and imported by every job
#let company = theme.minimal.with(json("design/brand.json"), tokens: (contrast: "strict"))
// invoice.typ
#show: invoice.with(theme: company, locale: locale.at(d.locale), zugferd: "en16931", ..d.header)
```

`layout: auto` picks A4/DIN or Letter/#10 per invoice region. The theme is an immutable value. DTCG import (`theme.from-tokens`) is a later COULD, and it is just a knob-dict producer.

**P6 Design studio, Stripe-like with a band and a DIN window**

```typst
#show: invoice.with(theme: theme.modern.with(
  logo: image("mark-white.svg", alt: "Atelier Nord"), color: rgb("#111827"), accent: rgb("#6366f1"),
  font: "Inter", heading-font: "Fraunces", layout: "din-5008-b",
  totals: (emphasis: "accent", width: 45%),
  payment: it => block(fill: it.tokens.colors.accent.lighten(90%), inset: 1em, radius: 4pt, (it.default)()),
))
```

**P7 Accessibility-bound supplier**

```typst
#show: invoice.with(theme: theme.classic.with(logo: image("sw.svg", alt: "Stadtwerke Musterstadt"),
  color: rgb("#00843d"), medium: "digital", tokens: (contrast: "strict")))
// typst compile --pdf-standard a-3a,ua-1   (verified clean for classic/modern/plain)
```

**P8 US subsidiary on Letter, same brand as the parent**

```typst
#import "corporate.typ": acme
#show: invoice.with(locale: locale.en-us,
  theme: acme.with(layout: "us-letter-10", footer: ([Remit to: ACME Inc., PO Box 1, Austin TX], [billing\@acme.com])))
```

**(9) Theme-package author.** Ship `knobs` and an optional `layout` dict, as in §6. Test locally with `theme.build("fjord", knobs)` against the invoice-pro version you target. The knob validator reports unknown keys on newer versions instead of silently ignoring them.

**(10) Scoped style on one subtree**

```typst
#line-items[
  #item([Consulting], price: 900)
  #restyle(stripes: rgb("#fef3c7"))[
    #group([Optional add-ons])[ #item([Extended support], price: 300) ]
  ]
]
#restyle(color: rgb("#b91c1c"))[ #payment-goal(days: 7) ]    // reminder-style emphasis for this block only
```

---

## 8. Validation & error messages

**When:** knob names are checked at `.with`/call time (sink check); everything else at resolution (once, before weave) and at each `restyle`; the compliance output check runs at render. All of these messages were verified:

| Case                        | Message                                                                                                                                                                          |
| --------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------- |
| typo in a named knob        | `theme: unknown option `colour`in`theme.classic`. Did you mean `color`? Known options: logo, color, …`                                                                           |
| typo in a data file         | `theme: unknown option `colr`in`patch #1`. Did you mean `color`? …`                                                                                                              |
| typo in a part option       | `theme: unknown option `row-fil`in`table`. Did you mean `row-fill`? Known options: render, row-fill, header, rule, column-order.`                                                |
| unknown layout              | `theme: unknown option `din-5008-c`in`layout`. Did you mean `din-5008-a`? Known options: din-5008-a, din-5008-b, sn-010130-right, us-letter-10, a4.`                             |
| legal part hidden           | ``theme: `notes` cannot be `none`: it carries legally required content (…). Restyle it with options, or pass a function `it => ...` that renders `it.data`.``                    |
| low contrast, strict        | ``theme: contrast of `tokens.colors.primary-text` on `white` is 1.53:1, below WCAG AA 4.5:1 (tokens.contrast: "strict"). Pick a darker brand color or set the role explicitly.`` |
| logo path without loader    | ``theme: `brand.logo` is the path "logo.svg". Packages cannot open files by path; pass `assets: p => image(p)` from your document, or `logo: image("logo.svg", alt: ..)`.``      |
| wrong color value           | ``theme: `brand.color` ("teal") must be a color: use rgb(..) or a hex string like "#0f766e".``                                                                                   |
| type error (generic)        | ``theme: `tokens.sizes.body` ("11") must be of length                                                                                                                            | relative`` |
| non-theme passed to invoice | `invoice::theme must be a theme preset such as `theme.classic` …; the given function returned <type>.`                                                                           |

**Unknown keys** are always rejected, at every depth, with a "did you mean" hint. The locale factory's silent-ignore behaviour and its broken `str(array)` panic are not copied.

**Low contrast:** `"auto"` fixes it silently (derives `primary-text`, picks `on-primary`); `"strict"` panics; `"off"` leaves it to the author. Typst has no warning API, so there is no warn level.

**PDF/A assets (proposed, not implemented):** when `env.zugferd != none`, a `stationery`/`logo` that is an `image` whose source ends in `.pdf` panics with _"PDF images cannot be embedded under PDF/A-3 (ZUGFeRD). Convert the letterhead to SVG."_ `cmyk()` in any color role panics likewise. Fonts cannot be checked: no introspection exists, so the docs point to `--font-path`, and a later `theme.specimen` makes silent fallback visible.

---

## 9. Internals sketch

```
src/theme/
  theme.typ     facade (curated exports)
  base.typ      master schema + compliance-parts list (defaults defined ONCE)
  layouts.typ   geometry presets + region->layout map (data)
  presets.typ   classic/modern/minimal/plain = build(name, knob-dict)
  resolve.typ   knob list, normalize, cascade, validate, derive, build(), restyle
  parts.typ     built-in renderers (token-only) + render-part dispatcher (`it` view)
  frame.typ     page frame (replaces letter-pro)
  blocks.typ    footer/header blocks
  palette.typ   contrast / on / ensure-contrast / oklch tint
  util.typ      merge-deep, replace, did-you-mean, string->length/color coercion
```

**Plumbing.** `invoice()` does `theme-fn(env: ..)` and puts the result in `inputs.theme`: **one ctx key**. The resolved dict carries `brand, tokens, page, parts, medium, hidden, source` (the unresolved specs, so `restyle` can re-resolve) plus internal adapters (`document: frame`, `line-items: (ctx, v, b) => render-part(ctx, "table", v, body: b)`, …). Components stay unchanged (`(ctx.theme.x)(ctx, view)`). In v0.5 proper they call `render-part(ctx, "bank", data)` directly and the adapters disappear.

**Built-in renderers read tokens only.** The `table` part maps tokens onto the existing generic line-items engine (roughly 30 of its parameters), which becomes a private implementation detail. The 5-place default duplication collapses into `base.typ`.

**Performance.** Resolution is once per compile (comemo-memoized on incremental recompiles) and once per `restyle` scope. No per-component default merging, nothing large injected into ctx, one wrapper motif level per `restyle` (well within the ~19-level budget).

**Compiler.** Only 0.14-era features are used: no `dictionary.map/filter`, no `path()`. The logo loader uses a closure, which works across package boundaries (verified with a local package). **I do not recommend bumping to 0.15.** The prototype ran only on 0.15.1, so a 0.14.0 CI run is mandatory in M1.

**loom improvements (nice to have; the design works on 0.1.1 as-is):**

1. a deep-merging `apply`, making `restyle` a thin alias;
2. fix the labelled-container crash so users can label wrappers as style hooks;
3. export `matcher.display`;
4. a version-independent motif key, or a stable alias, so theme packages could ship motifs;
5. fix the `observer` typo;
6. `ensure` with a `none-is-value` flag.

---

## 10. Feasibility evidence

Prototype: `<session>/proto-user-first/`. Built with `typst compile --root . tests/<f>.typ out/<f>-{p}.png`. Outputs are in `out/`.

| File                                              | Verified                                                                                                                                                                                                                                                                |
| ------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `tests/f0-default.typ`                            | no `theme:` argument gives `classic` plus `din-5008-a` from region `de`. Visually matches legacy DIN (`out/legacy-vs-new.png`: legacy / new / plain); page 2 reads "Seite 2 von 2"                                                                                      |
| `tests/f1-din-brand.typ`                          | rung 1+2: logo, one color (derived teal stripe), Inter, **every-page 4-column legal footer from blocks (#18)**                                                                                                                                                          |
| `tests/f2-us-modern.typ`                          | **same body, same brand, US Letter #10 plus the modern band style**: info block, English labels, "Page 1 of 2" (lang fix), continuation header on page 2, accent totals                                                                                                 |
| `tests/f3-toml-minimal.typ`                       | brand spread from **TOML** (`..toml(..).brand`), logo via the `assets` loader (resolves relative to the document), digital A4, **two scoped overrides**: one group's rows highlighted, payment block in red with totals outside unchanged                               |
| `tests/f4-rungs.typ` (+ `--input output=print`)   | company theme module (`tests/acme.typ`), DIN B, SVG stationery first/rest, wrapped payment, re-parameterized letterhead default, replaced signature; **pre-printed mode** hides letterhead, stationery and footer columns but keeps page numbers (`out/f4-compare.png`) |
| `tests/f5-custom-format.typ`                      | **new format with no fork** (A5 landscape dict plus letterhead function); called form `theme.minimal(..)` equals the `.with` form                                                                                                                                       |
| `tests/f6-kind.typ`                               | `kinds: (reminder: (color: red))`: reminder primary `#b91c1c`, logo kept, stripe re-derived (asserts)                                                                                                                                                                   |
| `tests/f7-dict-theme.typ`                         | `theme: (color: .., stripes: none)` dictionary accepted; passes `--pdf-standard ua-1`                                                                                                                                                                                   |
| `tests/f8-zugferd.typ`                            | branded theme plus SVG stationery plus ZUGFeRD `basic` compile under **`a-3b` and `a-3a,ua-1`**; factur-x.xml attached, `dc:title` and ZUGFeRD keywords present (metadata now from core)                                                                                |
| `tests/f9-plain.typ`                              | `theme.plain` (successor of `blank`) passes **`ua-1`** (old `blank` failed: no title)                                                                                                                                                                                   |
| `tests/errors/e1…e9`                              | all messages in §8                                                                                                                                                                                                                                                      |
| `exp/with.typ`                                    | `.with` replaces dict-valued named args wholesale (the reason for flat knobs)                                                                                                                                                                                           |
| `exp/sub/user3.typ` + `exp/pkgs/local/loadertest` | a loader closure resolves paths relative to the user file across a real package boundary                                                                                                                                                                                |
| timing                                            | same body, 3 runs: legacy 664–1056 ms, new classic 776–804 ms, minimal+TOML+2 restyles 673–870 ms                                                                                                                                                                       |

**Failed along the way and fixed:**

- `return` is a Typst keyword and cannot be a dict key; the zone field was renamed `return-height`.
- Part-level role aliases (`rule: "primary"`) were not resolved at first.
- The page number was duplicated in the continuation header and the footer.
- Stationery SVGs rendered at their natural size; they are now stretched to the sheet.
- A user letterhead renderer overrode `medium: "pre-printed"`. `medium` became a mode that wins over styling.
- `tokens.contrast: "strict"` silently fixed `primary-text`; strict now never auto-fixes.

**Not verified:**

- Typst 0.14.0.
- Legal notes and EPC payload moving into measure: they are still inside the renderers in the prototype.
- The `notes` empty-output check, reserved zones and `theme.immune`.
- The Swiss, French and UK geometries against postal masks.
- The PDF-asset guard.
- Filled table headers: the known spacer-column gap from the research (E17) remains.

**Pixel parity** with legacy is close but not exact: the body flow starts about 3mm higher, and the page number is 7.5pt muted instead of body-size black. Both are tunable in the classic preset before refs are regenerated.

---

## 11. Trade-offs, risks & rejected alternatives

**Weaknesses**

- **29 named knobs** is a long signature. It is discoverable with autocomplete and one docs table, but longer than the locale helpers.
- The **`.with` wholesale rule** for dict-valued named knobs (`table:`, `tokens:`) remains a trap when two named `.with` calls set the same knob. It is documented; positional dicts are the layering tool.
- **Two ways to pass a brand file**: spread (`..toml(..).brand`, flat keys) or positional (model-shaped). Both are the same vocabulary, but docs must show which is which.
- The **table part is still a monolith** internally. Per-column and per-cell renderers (custom columns, SKU) are out of v0.5 scope; `table.data.columns` is the seam for later.
- **`restyle` capture** only reaches row fill for items today. Generalizing it (text color, group header rows) needs the table renderer to consume a per-entry style record.
- **Region-derived layout** couples locale and theme. It is only a default, and CH is deliberately kept on DIN until SN geometry is verified.
- **Owning the page frame** means invoice-pro now maintains DIN geometry itself (about 80 lines) and becomes responsible for postal correctness of every shipped layout.

**Deliberately left out:** CMYK and bleed (Typst limitation); font files; W3C DTCG import (a later adapter that emits knobs); a warning level (no API); theme-supplied component default arguments (MUI `defaultProps`: blurs data and presentation, and `columns.forced` covers the #41-type need); elembic and valkyrie (rejected in the research).

**Rejected alternatives**

- **A `brand:` dict as the primary knob:** the chain-unsafe `.with` semantics were verified to lose keys.
- **A `themes.custom.*` helper DSL like `locale.custom`:** a second vocabulary, and the locale block form has a verified patch-loss bug. Knob dicts are already the DSL, validated with did-you-mean.
- **Keeping letter-pro:** it blocks every-page footers, non-A4 paper, stationery, localized numbering and non-DIN windows.
- **Implicit cetz-style inheritance:** explicit derivation plus role aliases give the same one-seed effect with less magic.
- **Separate `layout:` and `theme:` parameters on `invoice`:** one reusable value is what companies want; `layout` is a knob inside it.

**Would mark experimental:** `modern`/`minimal` visuals, non-DIN layouts, `kinds`, `reserved`/`immune`, `it.ctx`, `table.data` until M4.

---

## 12. Implementation roadmap (solo maintainer, each milestone shippable)

| M                                      | Scope                                                                                                                                                                                                                                          | Tests                                                                                                                                                       |
| -------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **M1 Core resolver**                   | `theme/` util, base, resolve (knobs, merge, validate, derive), `invoice()` evaluation plus `env`, core PDF metadata in root, `lang` fix; components unchanged via adapters; `classic` renders via the **existing** DIN document and line items | unit tests for merge/derive/errors (`tests/unit/theme-*`, messages asserted); all existing visual refs unchanged; CI on typst **0.14.0**                    |
| **M2 Page frame**                      | `frame.typ` plus DIN A/B layouts; drop letter-pro; localized page numbers (`strings.document.page`); marks tokens                                                                                                                              | regenerate the ~20 DIN refs one by one (fix-tests skill); `tests/integration/frame-din-a`, `frame-din-b`; a-3b plus ua-1 compile checks                     |
| **M3 Brand & furniture**               | brand knobs, palette derivation, logo plus `assets`, footer blocks (#18), continuation header, stationery, `medium`                                                                                                                            | `integration/brand-seed`, `footer-legal` (closes #18), `stationery-first-rest`, `medium-pre-printed` (sys.inputs); `docs/api-theme-*` for every doc snippet |
| **M4 Data contract & compliance core** | clean `it.data` (Money/Rate records, plurals), notes/zero-tax decisions into measure, EPC payload into core, `render-part` called by components directly, compliance output check                                                              | rewrite issue-39/41 tests against `totals` knobs and `it.data`; `tax-exemption-grounds` asserts on `table.data.notes`; ZUGFeRD validation unchanged         |
| **M5 Presets & layouts**               | `modern`, `minimal`, `plain` (retire `blank`: mechanical migration of ~25 tests to `theme.plain`), `us-letter-10`, `a4`, experimental SN/NF/UK                                                                                                 | one visual test per preset × 2 layouts; thumbnail regeneration                                                                                              |
| **M6 Scope & ecosystem**               | `restyle` (row capture generalized), `kinds`, `theme.build` docs page "publish a theme package", `theme.specimen`                                                                                                                              | `integration/restyle-group`, `kinds-reminder`; a local test package in `tests/pkgs/`                                                                        |
| **M7 Freeze v0.5.0**                   | docs trio `theme/index.md` (use), `theme/custom.md` (knobs, parts, packages), `theme/base.md` (schema tables generated from `base.typ` with a coverage test: knob list equals the normalize branches)                                          | docs registry complete; breaking-changes section in release notes                                                                                           |

M1 plus M2 already deliver the maintainer's most-requested outcome, the locale-correct DIN invoice owned by invoice-pro. M3 closes #18 and the README promise "accent colors and fonts to match corporate identities".
