# invoice-pro v0.5.0 Theming API: "structure-first"

**Lens:** a theme is a _composition_. invoice-pro owns a **page master** (the _layout_): a set of
named **regions**, each with geometry and a page selector, that **host parts**. A **part** is a
renderer with a stable view contract. It can be wrapped ("wrap, don't eject") or replaced. Style
tokens exist, but they are the smallest of the three axes. Every format in this document (DIN 5008
A/B, SN 010130 + QR-bill zone, NF Z 11-001, UK C5, US Letter #10, Stripe-like digital, colour band,
pre-printed stationery, an A5-landscape sidebar receipt from a third-party package) is a **data
definition of 10-30 lines**. Twelve of them were compiled from **one unchanged invoice body** (section 10).

Prototype: `scratchpad/proto-structure-first/` (about 1,300 lines under `src/theming/`, letter-pro
removed from the render path, compiled with typst 0.15.1).

---

## 1. Pitch & mental model

Every invoicing product separates _page master_ (paper, window, letterhead, footer zones) from
_content style_. KOMA-Script's `.lco` files are the closest prior art: stackable bundles of
geometry that each describe a national letter standard. invoice-pro today fuses both into
`themes.DIN-5008(...)` and hands the geometry to a third-party package (letter-pro) that
hard-codes A4, background, footer-on-page-1 and German/English page labels. This proposal turns
that inside out:

- **Layout** = plain data: `paper`, `margin`, `marks`, `stationery`, and `regions` (a dict of named
  rectangles or flow slots). A region says _where_ (`place`, `x|right`, `y|bottom`, `width`,
  `height`), _when_ (`pages: "first" | "rest" | "last" | "not-last" | "all"`) and _what_ (`parts:
("logo", "sender")`, in reading order) plus a few presentational fields (`arrange`, `align`,
  `inset`, `fill`, `brand`, `isolate`, `float`).
- **Parts** = a flat dict of renderers `(ctx, view) => content`. There are _frame parts_
  (`logo`, `sender`, `recipient`, `info-block`, `legal-footer`, `page-number`, ...) placed by the
  layout, and _body parts_ (`line-items` -> `items-table` / `totals` / `notices`, `bank-details`,
  `payment-terms`, `signature`) called by the components the user writes in the body. Any part can
  be `wrap`ped (the wrapper receives the inherited renderer as `inner`) or replaced.
- **Tokens + options** = the small style layer: semantic colour/font/size/stroke roles
  (`auto` = derived, for example `on-primary` by WCAG contrast) and per-part structural knobs
  (`options.items-table.zebra`, `options.logo.image`, ...).
- A **theme** = `layout x parts x (options, tokens)`. It is a lazy function like a locale. It is
  folded from layers with one deep-merge engine and one patch DSL (`themes.custom`). The result
  is one immutable dict under **one** ctx key (`ctx.theme`).
- The **core, not the theme**, emits everything that is compliance-critical: PDF metadata,
  `text.lang`, the ZUGFeRD attachment, and legal _decisions_ (which notices are required, zero-tax
  suppression, the EPC payload). The theme only decides how that output looks.

```
                         ┌────────────────────────── THEME (one dict in ctx.theme) ─────────────────────────┐
  themes.din-5008  ──►   │  layout ─────────────► regions ──hosts──► parts ◄──called by── components        │
  .with(                 │  (page master, data)   (geometry,        (renderers,          (line-items,       │
    layout: layouts.X,   │   paper/margin/marks    pages, place,     view contract,       bank-details,      │
    brand-patch,         │   stationery)           arrange, brand,   wrap/replace)        payment-goal, ...) │
    { import             │                         isolate)             ▲                                     │
      themes.custom: *   │  options ── per-part knobs ─────────────────┤                                     │
      region(..)         │  tokens  ── semantic roles (auto=derived) ──┘                                     │
      wrap(..) ... })    └───────────────────────────────────────────────────────────────────────────────────┘
                                   ▲ merge order: base → preset(layout+look) → named args → patches
                                   │                                  → #themed[..] scopes (parts/options/tokens only)
  CORE (not themable):  set document(..) · set text(lang) · pdf.attach(factur-x.xml) · legal decisions in measure
                         └──► render-frame(ctx, body): one top-level set page(header/footer/background/foreground)
                              + first-page fixed regions (in flow, tagged) + before-regions + BODY + after-regions
```

Two axes are orthogonal and swappable in one argument each:

```
            looks →   classic        minimal        bold
layouts ↓
din-5008-a            themes.din-5008   (.with(looks))    ...
sn-010130-right       themes.din-5008.with(layout: layouts.sn-010130-right)
modern (digital)                     themes.modern
band                                                  themes.band
<your layout dict>    themes.blank.with(layout: my-layout, my-look)
```

---

## 2. Public API surface

### 2.1 What `#import "@preview/invoice-pro:0.5.0": *` adds or changes

| Export               | Kind                  | Content                                                                                                                                                                                                                      |
| -------------------- | --------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `invoice(theme: ..)` | changed param         | `function \| dictionary`, default `themes.din-5008` (uncalled)                                                                                                                                                               |
| `themes`             | module                | presets `din-5008`, `modern`, `band`, `blank`; `custom` (patch DSL); `build` (tier-2 factory); `looks`; `parts` (`parts.frame.*`, `parts.body.*` default renderers, for wrapping or copying); helpers `contrast`, `on-color` |
| `layouts`            | module                | page masters (plain dicts): `din-5008-a`, `din-5008-b`, `sn-010130-right`, `sn-010130-left`_, `nf-z-11-001`, `uk-c5`, `us-letter-10`, `modern`, `band`, `plain`; `derive(base, ..patches)`_                                  |
| `themed`             | bare function (motif) | subtree override with the same patch fragments as `themes.custom`                                                                                                                                                            |

`*` = specified here, not in the prototype (trivial: `sn-010130-left` is a region patch,
`derive` is the merge engine applied to a layout).

Namespace rule kept: _values passed to a parameter live in a namespace named after it_.
`theme:` takes `themes.*`. `layouts.*` values go into `theme` through `layout:` or `custom.layout(..)`.
`themed` is a verb written in the body, so it is a bare function like `line-items` or `apply`.

### 2.2 Theme presets and the factory

```typst
/// Builds a lazy theme from preset layers (tier 2: theme authors, Typst Universe packages).
///
/// Pass the result **uncalled** (`theme: my-theme`); customise it with
/// `.with(..patches, layout: .., tokens: .., options: .., parts: ..)`.
/// `invoice()` evaluates it once with the running package's base theme, so a theme
/// built against v0.5.0 automatically receives keys added in later versions.
/// Calling it yourself (`my-theme()`) evaluates eagerly against this package's own base.
///
/// -> (..patches, base: auto) => dictionary
#let build(
  /// Patch fragments (dicts in patch shape or `themes.custom` helper results),
  /// applied left to right on top of the base theme.
  /// -> dictionary | array
  ..layers,
) = ...

/// DIN 5008 business letter, form A (layout `layouts.din-5008-a`, look `looks.classic`).
/// -> (..patches, base: auto) => dictionary
#let din-5008 = build(layout-swap(layouts.din-5008-a), looks.classic)
/// Digital-first, Stripe-like document: no window, no marks, everything flows.
#let modern = build(layout-swap(layouts.modern), looks.minimal)
/// Full-bleed colour band above a DIN form B window.
#let band = build(layout-swap(layouts.band), looks.bold)
/// No page furniture at all (regions: (:)); default body parts. Replaces the old `blank`.
#let blank = build(layout-swap(layouts.plain), looks.classic)
```

The lazy theme's parameters:

```typst
/// -> dictionary
(
  /// Patch fragments applied last, in order (brand, then user tweaks).
  /// -> dictionary | array
  ..patches,
  /// Swap the page master wholesale (regions REPLACED, not merged).
  /// -> dictionary
  layout: <unset>,
  /// Token / option / part patches (deep-merged) - shorthands for positional patches.
  /// -> dictionary
  tokens: <unset>, options: <unset>, parts: <unset>,
  /// The base theme to fold onto; injected by `invoice()`.
  /// -> auto | dictionary
  base: auto,
) => dictionary
```

**Calling convention: lazy and passed uncalled, like `locale.de-de`.** Because `base: auto` is
_named_, the called form `themes.din-5008()` also works and returns an evaluated dict, which
`invoice` accepts as well (verified, `tests/errors/e8-called-ok.typ`). This removes the old
footgun (I-4/I-5) _by construction_ rather than by documentation. `themes.din-5008` and
`themes.din-5008()` are both correct. Neither can silently yield an unstyled page, because the
evaluated value is validated (`invoice::theme must evaluate to a theme dictionary ...`). The
uncalled form is recommended. It is the only form that receives the _running_ package's base,
which gives the same forward-compatibility promise the locale docs make.

### 2.3 `themes.custom`: the patch DSL

Every helper returns a **one-element array** (no `return` inside the array), so the block form
composes. This deliberately avoids locale bug I-1. The block form is covered by a test
(`tests/demo.typ` uses a three-helper block).

```typst
/// Swaps the page master (regions are replaced, not merged).      -> array
#let layout(value)
/// Paper name or (width:, height:).                               -> array
#let paper(value, flipped: auto)
/// Text-area margins (deep-merged: set only what you change).      -> array
#let margin(top: auto, bottom: auto, left: auto, right: auto)
/// "generated" | "pre-printed" | (first: content, rest: content)   -> array
#let stationery(value)
/// Print marks: none (digital) | (fold:, punch:, x:, length:, stroke:) -> array
#let marks(value)
/// Adds or patches a region; `region(name, none)` removes it.       -> array
#let region(name, ..fields)
/// Replaces a part: (ctx, view) => content, or none (hide).         -> array
#let part(name, renderer)
/// Wraps the inherited renderer: (ctx, view, inner) => content.     -> array
#let wrap(name, wrapper)
/// Per-part structural options.                                     -> array
#let options(name, ..fields)
/// Logo content (image(..) with alt, or any content) and height.    -> array
#let logo(image, height: auto)
/// Semantic colour roles; auto = untouched.                         -> array
#let colors(primary: auto, on-primary: auto, text: auto, muted: auto, subtle: auto,
            rule: auto, surface: auto, negative: auto, positive: auto, label: auto)
#let fonts(body: auto, heading: auto, numeric: auto)               // -> array
#let sizes(base: auto, small: auto, fine: auto, large: auto, title: auto)  // -> array
#let strokes(thin: auto, regular: auto, thick: auto)               // -> array
```

Typed named parameters give Typst-native strictness for free: `colors(primry: red)` fails with
`unexpected argument: primry` (verified, e7). Raw dict patches (`(tokens: (color: (primary: red)))`)
are always accepted. That is the brand-file target, and it is validated strictly (section 8).

### 2.4 `themed`

```typst
/// Re-themes a subtree. Takes the same patch fragments as `themes.custom`; they are
/// deep-merged into the inherited theme at scope time. Tokens, options and parts only:
/// the page master is document-level.
///
/// -> content
#let themed(
  /// -> dictionary | array
  ..patches,
  /// -> content
  body,
) = compute-motif(
  scope: ctx => ctx + (theme: scope-theme(ctx.theme, patches.pos())),
  measure: (_, children) => children,
  body,
)
```

`themed` is an _unnamed_ compute motif. It does not extend `sys.path`, so `group`/`item`
direct-parent guards keep working inside it (verified: `themed` wrapped around a `group` inside
`line-items`). The shallow `apply` stays for data keys and is documented as "not for theming".

### 2.5 How it is passed to `invoice`

```typst
#show: invoice.with(theme: themes.din-5008)                                   // default
#show: invoice.with(theme: themes.din-5008.with(layout: layouts.us-letter-10)) // swap page master
#show: invoice.with(theme: themes.modern.with(brand))                          // brand = patch block
#show: invoice.with(theme: acme.theme)                                         // third-party lazy theme
```

---

## 3. Schemas

All defaults are defined **once**, in `src/theming/schema.typ`. Presets, looks, brand files and
user patches are deltas against it.

### 3.1 Theme dict (the value in `ctx.theme`)

| Key          | Type                                     | Meaning                                                                           |
| ------------ | ---------------------------------------- | --------------------------------------------------------------------------------- |
| `meta`       | `(name: str, version: str)`              | provenance                                                                        |
| `layout`     | layout dict (3.2)                        | page master                                                                       |
| `parts`      | `dict<str, function \| none>`            | renderers by name. Open set: custom regions may reference custom part names       |
| `options`    | dict (3.5)                               | per-part structural knobs. Closed per built-in part, plus `options.custom` (open) |
| `tokens`     | dict (3.4), **resolved**                 | what parts read                                                                   |
| `token-spec` | dict (3.4), **unresolved** (`auto` kept) | internal. Lets `themed` re-derive after a scoped `primary` change                 |

### 3.2 Layout (page master)

| Key                               | Type                                                                                              | Default          | Meaning                                                                                                                            |
| --------------------------------- | ------------------------------------------------------------------------------------------------- | ---------------- | ---------------------------------------------------------------------------------------------------------------------------------- |
| `name`                            | `str`                                                                                             | `"plain"`        | identifier (shown in errors)                                                                                                       |
| `paper`                           | `str \| (width: length, height: length)`                                                          | `"a4"`           | Typst paper name or custom size                                                                                                    |
| `flipped`                         | `bool`                                                                                            | `false`          | landscape                                                                                                                          |
| `margin`                          | `(top, bottom, left, right: length)`                                                              | `20/20/25/20mm`  | text area of continuation pages (left/right/bottom also on page 1). Deep-merged                                                    |
| `header-ascent`, `footer-descent` | `relative`                                                                                        | `30%`            | passed to `set page`                                                                                                               |
| `body-top`                        | `auto \| length`                                                                                  | `auto`           | page-absolute y where the body starts on page 1. `auto` = below the lowest _reserving_ first-page fixed region + `body-gap`        |
| `body-gap`                        | `length`                                                                                          | `4.23mm` (12 pt) |                                                                                                                                    |
| `stationery`                      | `"generated" \| "pre-printed" \| (first: content, rest: content)`                                 | `"generated"`    | anything other than `"generated"` suppresses `brand: true` regions. The dict form also draws the letterhead as the page background |
| `marks`                           | `none \| (fold: array<length>, punch: none \| length, x: length, length: length, stroke: stroke)` | `none`           | geometry read by the `marks` part                                                                                                  |
| `regions`                         | `dict<str, region \| none>`                                                                       | `(:)`            | ordered, named. `none` = removed                                                                                                   |

### 3.3 Region

| Key                                | Type                                                                                                     | Default                           | Meaning                                                                                                                                                                                          |
| ---------------------------------- | -------------------------------------------------------------------------------------------------------- | --------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `place`                            | `"fixed" \| "before" \| "after" \| "header" \| "footer" \| "background" \| "foreground"`                 | `"fixed"`                         | _fixed_: page-absolute rectangle. _before_/_after_: in the body flow before or after the user body. _header_/_footer_: running zones in the margins. _background_/_foreground_: full-page layers |
| `pages`                            | `"all" \| "first" \| "rest" \| "last" \| "not-last"`                                                     | `"first"`                         | page selector (resolved with `here()` / `counter(page).final()`)                                                                                                                                 |
| `x` \| `right`                     | `auto \| length \| relative`                                                                             | `auto`                            | exactly one for `fixed`. `right` anchors from the paper's right edge (Swiss/French windows are specified this way)                                                                               |
| `y` \| `bottom`                    | `auto \| length \| relative`                                                                             | `auto`                            | exactly one for `fixed`. `bottom` needs `height`                                                                                                                                                 |
| `width`, `height`                  | `auto \| length \| relative`                                                                             | `auto`                            | `auto` width = paper width (fixed) or text width (flow)                                                                                                                                          |
| `parts`                            | `array<str \| content \| (ctx, view) => content>`                                                        | `()`                              | hosted parts, **in reading order**                                                                                                                                                               |
| `arrange`                          | `"stack" \| "row" \| (columns: array, align: ..) \| (rows: array, align: ..) \| (ctx, cells) => content` | `"stack"`                         | how the parts are laid out                                                                                                                                                                       |
| `gap`                              | `length`                                                                                                 | `0.6em`                           |                                                                                                                                                                                                  |
| `align`, `inset`, `fill`, `stroke` | Typst types                                                                                              | `top+left`, `0pt`, `none`, `none` | box of the region                                                                                                                                                                                |
| `brand`                            | `bool`                                                                                                   | `false`                           | brand furniture: dropped when `stationery != "generated"` (geometry is kept)                                                                                                                     |
| `isolate`                          | `bool`                                                                                                   | `false`                           | brand-immune scope: neutral tokens, reset typography (regulated zones)                                                                                                                           |
| `float`                            | `bool`                                                                                                   | `false`                           | `place: "after"`: float to the paper's bottom edge; reserves space in the flow, moves to the next page if it does not fit                                                                        |
| `reserve`                          | `auto \| bool`                                                                                           | `auto`                            | whether a fixed region pushes `body-top` down (`auto` = yes for `pages: "first"`, no for overlays)                                                                                               |
| `text`                             | `dict`                                                                                                   | `(:)`                             | extra `set text(..)` args inside the region                                                                                                                                                      |

Only `pages: "first"` fixed regions are laid out **in flow**, so they are tagged content in
reading order. That matters for the address under PDF/UA. All other fixed regions and all
header/footer/background/foreground regions are page furniture (artifacts).

### 3.4 Tokens (secondary axis)

```typst
(
  color: (primary: rgb("#1f2937"), on-primary: auto /* WCAG black|white */, text: black,
          muted: luma(100), subtle: luma(80), rule: black, surface: rgb("e2e8f0"),
          negative: rgb("b22222"), positive: rgb("333333"), label: rgb("475569")),
  font:  (body: "Liberation Sans", heading: auto /* = body */, numeric: auto /* = body */),
  size:  (base: 10pt, small: 0.85em, fine: 7pt, large: 1.2em, title: 1.4em),
  stroke: (thin: 0.5pt, regular: 1pt, thick: 2pt),
)
```

These are the ~22 informal tokens of `base-theme/line-items.typ:5-39`, renamed to semantic roles.
The current values stay the defaults, so the default look is unchanged in hue.

### 3.5 Options (per-part knobs; a part reads only its own key)

```typst
(
  logo:         (image: none, height: 14mm),
  items-table:  (zebra: (none, auto) /* auto = tokens.color.surface */, header-fill: none,
                 header-text: auto, column-order: ("quantity", "unit-price", "tax-rate", "total-price"),
                 repeat-header: true),
  totals:       (width: 66%),
  bank-details: (qr: true, qr-size: 5em),
  page-number:  (from: 2, format: auto /* locale label | (current, total) => content */),
  legal-footer: (columns: auto),
  title:        (show-place-date: true),
  row:          (fill: none),     // captured by group/item inside a `themed` scope (section 4.6)
  custom:       (:),              // open namespace for third-party parts
)
```

Option values may be **lazy token references**: `header-fill: t => t.color.primary`. This is
the DTCG alias idea without a string parser, and it keeps options in sync with scoped token changes.

### 3.6 Built-in parts (names frozen in v0.5.0)

Frame: `logo, sender, sender-extra, return-address, annotations, recipient, references,
info-block, title, legal-footer, page-number, continuation, marks, masthead, parties, band,
band-title` (+ `qr-bill` reserved name for the future Swiss component).
Body: `line-items, items-table, totals, notices, bank-details, payment-terms, signature`.

### 3.7 DIN 5008 form A (the default), complete

```typst
#let din-5008-a = (
  name: "din-5008-a",
  paper: "a4",
  margin: (top: 20mm, bottom: 30mm, left: 25mm, right: 20mm),
  marks: (fold: (87mm, 192mm), punch: 148.5mm, x: 5mm, length: 2.5mm, stroke: 0.25pt + black),
  regions: (
    marks: (place: "background", pages: "all", parts: ("marks",)),
    letterhead: (x: 25mm, y: 10mm, width: 165mm, height: 17mm, brand: true,
      parts: ("logo", "sender"), arrange: (columns: (1fr, auto), align: (left + horizon, right + top))),
    address: (x: 20mm, y: 27mm, width: 85mm, height: 45mm, inset: (left: 5mm),
      parts: ("return-address", "recipient"),
      arrange: (rows: (17.7mm, 27.3mm), align: (left + bottom, left + top))),
    info: (x: 125mm, y: 32mm, width: 75mm, height: 40mm, parts: ("sender-extra",)),
    references: (place: "before", parts: ("references",)),
    title: (place: "before", parts: ("title",)),
    continuation: (place: "header", pages: "rest", parts: ("continuation",)),
    page-number: (place: "footer", pages: "all", parts: ("page-number",), align: right),
    legal: (place: "footer", pages: "all", brand: true, parts: ("legal-footer",)),
  ),
)
#let din-5008-b = din-5008-a + (name: "din-5008-b",
  marks: din-5008-a.marks + (fold: (105mm, 210mm)),
  regions: din-5008-a.regions + (
    letterhead: din-5008-a.regions.letterhead + (height: 35mm),
    address: din-5008-a.regions.address + (y: 45mm),
    info: din-5008-a.regions.info + (y: 50mm)))
```

### 3.8 Radically different layouts in the same schema

**Swiss SN 010130, right window + reserved QR-bill zone (brand-immune, bottom edge of last page):**

```typst
#let sn-010130-right = (
  name: "sn-010130-right", paper: "a4",
  margin: (top: 20mm, bottom: 22mm, left: 22mm, right: 18mm), marks: none,
  regions: (
    letterhead: (x: 22mm, y: 15mm, width: 80mm, height: 30mm, brand: true, parts: ("logo", "sender")),
    address: (right: 12mm, y: 50mm, width: 90mm, height: 40mm, parts: ("return-address", "recipient"),
      arrange: (rows: (10mm, 30mm), align: (left + bottom, left + top))),
    info: (x: 22mm, y: 55mm, width: 80mm, height: 35mm, parts: ("info-block",)),
    title: (place: "before", parts: ("title",)),
    page-number: (place: "footer", pages: "not-last", parts: ("page-number",), align: right),
    qr-bill: (place: "after", pages: "last", float: true, isolate: true,
      x: 0mm, width: 210mm, height: 105mm, parts: ("qr-bill-slip",)),
  ),
)
```

(The window millimetres are low-confidence: they come from a 2003 source and should be verified
against Swiss Post control masks. They are one data edit away.)

**Stripe-like digital document (no window, no absolute regions at all):**

```typst
#let modern = (
  name: "modern", paper: "a4", margin: (top: 18mm, bottom: 22mm, left: 20mm, right: 20mm), marks: none,
  regions: (
    masthead: (place: "before", parts: ("masthead",)),
    parties: (place: "before", parts: ("parties",), inset: (y: 4mm)),
    footer: (place: "footer", pages: "all", parts: ("legal-footer", "page-number"),
      arrange: (columns: (1fr, auto), align: (left, right + bottom))),
  ),
)
```

**A5 landscape receipt with a full-height brand rail on every page (from a third-party package):**

```typst
#let sidebar-a5 = (
  name: "acme-sidebar-a5", paper: "a5", flipped: true, marks: none,
  margin: (top: 12mm, bottom: 14mm, left: 72mm, right: 12mm),
  regions: (
    rail: (place: "background", pages: "all", x: 0mm, y: 0mm, width: 60mm, height: 100%,
      brand: true, parts: ("acme-rail",)),
    head: (place: "before", parts: ("acme-head",)),
    num: (place: "footer", pages: "all", parts: ("page-number",), align: right),
  ),
)
```

Also in the prototype, as small data: `us-letter-10` (Letter paper, #10 window, tri-fold marks at
3.667/7.333 in), `nf-z-11-001` (recipient at 110/50 mm, DL marks, legal footer), `uk-c5` (C5
half-fold mark at 148.5 mm, window 90x44 mm at 20/42 mm), `band` (full-bleed band background +
DIN-B window).

---

## 4. Cascade, precedence & merge semantics

### 4.1 Layers (lowest to highest)

| #   | Layer                             | Written as                                                                                               | Scope                              |
| --- | --------------------------------- | -------------------------------------------------------------------------------------------------------- | ---------------------------------- |
| L0  | package base theme                | `schema.typ` (injected by `invoice`)                                                                     | document                           |
| L1  | preset layers                     | `build(layout-swap(layouts.x), looks.y)`                                                                 | document                           |
| L2  | named swaps and shorthands        | `.with(layout: .., tokens: .., options: .., parts: ..)` (`layout:` first)                                | document                           |
| L3  | positional patches, in call order | brand block, then user tweaks: `.with(brand, { import themes.custom: *; ... })`; chained `.with` appends | document                           |
| L4  | scoped overrides, innermost wins  | `#themed(..)[..]` (nested scopes stack)                                                                  | subtree; tokens/options/parts only |
| L5  | explicit component arguments      | `bank-details(qr-code: (display: false))`, `line-items(show-column: ..)`                                 | one instance                       |

L5 rule: a component argument that has a theme counterpart defaults to `auto`, meaning
"inherit from `ctx.theme.options`" (loom `derive` semantics, explicit beats context). The prototype
still combines the old `qr-code.display` with `options.bank-details.qr` by AND. v0.5.0 would change
the component default to `auto`. Native Typst set rules sit outside the chain (unchanged facts:
body rules beat theme rules, pre-template rules lose). The frame therefore only issues
`set text(font, size, fill)`, `show heading: set text(font)` and `set par(justify)` for the body,
all driven from tokens.

### 4.2 Merge rules (one engine: `theming/merge.typ`, 80 lines)

| Patch value                     | Effect                                                                                                            |
| ------------------------------- | ----------------------------------------------------------------------------------------------------------------- |
| `auto`                          | untouched (skipped at every depth)                                                                                |
| `none`                          | a real value: "off". For a region it means "remove"; for a part, "render nothing" (rejected for compliance parts) |
| dict onto dict                  | **recursive merge, unlimited depth**. `margin(top: 30mm)` keeps left/right/bottom; `inset: (left: 5mm)` merges    |
| array                           | **replaces** (`column-order`, `parts`, `fold`)                                                                    |
| any other value                 | replaces                                                                                                          |
| `wrap-marker(fn)`               | composes with the value inherited _at that layer_: `(ctx, view) => fn(ctx, view, inherited)`                      |
| `replace-marker(dict)`          | replaces a dict wholesale (escape hatch, Tailwind `theme` vs `theme.extend`)                                      |
| `layout:` / `custom.layout(..)` | swaps the page master: `merge(base.layout, new)`. Regions are _replaced_, never merged across standards           |

Wrappers stack in layer order. A brand package can wrap `totals`, the user can wrap it again,
and a `themed` scope can wrap it a third time. Each wrapper receives the previous composition as
`inner` (verified: a document-level `wrap("totals")` combined with a scoped primary colour; see
`out-scoped-2.png`, where the bar takes the _scoped_ colour because the wrapper reads
`ctx.theme.tokens` at call time).

### 4.3 Derivation

After every fold, `derive-tokens(token-spec)` fills `auto` leaves: `on-primary` = black or white by
WCAG contrast (pure Typst, `color.linear-rgb`), `surface` = OKLab mix of primary and white (only if
the user sets `surface: auto`), `font.heading`/`font.numeric` = `font.body`. Because `token-spec`
keeps the `auto`s, a `themed(colors(primary: ..))` scope re-derives `on-primary` correctly. Lazy
option values (`t => t.color.primary`) are resolved at read time by the part.

### 4.4 When resolution happens and what it costs

- Document theme: once in `invoice()`, before `weave`. It is a pure function of its arguments
  (memoized by comemo on recompiles). Validation runs once.
- `themed`: at scope time. It runs in both loom passes (measure + draw), about 2 merges plus
  derivation plus validation per scope per pass. The theme is about 60 token/option leaves plus
  ~25 function values, far below the ~20 ns/leaf/call cost model's danger zone.
- Measured end-to-end (typst 0.15.1, whole process, 3 runs each): old DIN smoke test
  **375-392 ms** vs the same invoice on the new frame **403-412 ms** (+~7%, including frame parts that
  did not exist before: legal footer, marks, continuation header). The 2-page invoice with 3 nested
  scopes: **528-536 ms**.

### 4.5 `auto` and `none`, summarised

- In patches: `auto` = leave untouched.
- In tokens/options: `auto` = derived or computed by the engine.
- In component arguments: `auto` = inherit from the theme.
- `none` = explicitly off everywhere (`marks: none`, `region(.., none)`, `part("signature", none)`,
  `zebra: (none, none)`).

### 4.6 Scopes reach data-only motifs

`group`/`item` have no draw, so a subtree theme cannot restyle them by being in their ctx. The rule
here: **data components capture `ctx.theme.options.row` into their signal** (one small dict), and
the view carries it as `entry.style`. `themed(options("row", fill: ..))[#group(..)[..]]` therefore
highlights exactly one group, including its header, items and subtotal (verified,
`out-group-1.png`). This is the only place the theme touches measure. It is presentation-only and
never read by ZUGFeRD.

---

## 5. Renderer / part contract

### 5.1 Signature

**Every part is `(ctx, view) => content`.** There is no three-argument variant; a component's drawn
residue arrives as `view.body`. Wrappers are `(ctx, view, inner) => content`, where `inner` is
`(ctx, view) => content`. A wrapper may _transform the view_ before calling `inner` (for example,
filter entries or override a label), not just decorate the output. `ctx.theme` inside a part is the
_effective_ (possibly scoped) theme.

```typst
// replace
part("signature", (ctx, view) => [— #view.name])
// wrap
wrap("bank-details", (ctx, view, inner) => block(fill: ctx.theme.tokens.color.surface, inset: 8pt, inner(ctx, view)))
// eject: start from the shipped renderer
part("totals", (ctx, view) => { /* copy of */ themes.parts.body.totals /* then edit */ })
```

### 5.2 Views

**Frame view** (all frame parts receive the whole of it, so custom parts need no wiring):

| Key                   | Content                                                                                                                                    |
| --------------------- | ------------------------------------------------------------------------------------------------------------------------------------------ |
| `document`            | `(kind: "invoice", title, subject, number, date: str, place)`. `kind` is prepared for quote, credit note, delivery note and reminder (R27) |
| `sender`, `recipient` | normalized parties (`name`, `address`, `city`, `*-inline`, `extra` pairs, `vat-id`, `tax-nr`, `register`\*, `management`\*)                |
| `references`          | normalized `(label, value)` pairs (always normalized: it is built from root's draw ctx)                                                    |
| `bank`                | bank signal or `none` (fresh, not one pass stale)                                                                                          |
| `totals`              | `(total: (net, gross, due, prepaid: decimal), formatted: (..: str))`                                                                       |
| `page`                | `none` in flow regions; `(current: int, total: int)` in header/footer/background/foreground                                                |
| `layout`              | the resolved layout (e.g. `marks` geometry)                                                                                                |
| `region`              | `(name, width, height)` of the hosting region                                                                                              |

\* proposed sender keys for § 35a GmbHG / RCS footers (an invoice-header change adjacent to theming).

**Body views, "view v2" (frozen at v0.5.0).** They fix the research findings:

- **Raw and formatted together.** Every amount becomes `(value: decimal, text: str)`, every rate
  `(value: ratio, text: str)`, every date `(value: datetime | none, text: str)`. Themes can colour
  negatives or re-format without re-parsing strings (R10 of component-contract).
- **Consistent names and types:** `surcharges` (plural, item and global), `formatted` (not
  `formated`), `name`/`description` always `content`, `label` always `content | none`.
- **No stale ctx.** Everything a body part needs is in its view, built in the component's _draw-pass_
  measure (the view already comes from the draw pass). Body parts must not read `ctx.global`; that
  becomes internal. The frame view is built from root's draw ctx (fresh).
- **Decisions, not markup.** `view.notices: array<(kind, text, marker)>` is computed in measure
  (moving `global-info.typ`'s decision logic out of the renderer). `view.taxes` is already filtered
  (zero-rate rule). `view.qr: content | none` is the rendered EPC code (see 5.4). `view.required:
bool` tells the core whether legal output is present.
- The prototype still passes the current (v1) line-items view through an adapter. The v2 shape is
  specified here and is milestone M3.

### 5.3 Stability tiers (Docusaurus safe/unsafe)

| Tier                                   | Frozen in v0.5.0 | Examples                                                                                                                                                                                |
| -------------------------------------- | ---------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Stable**                             | yes              | part names (3.6) and the `(ctx, view)` signature; frame view keys; body view v2 keys; layout and region schema keys; token _roles_; patch DSL helper names; merge rules (4.2); `themed` |
| **Experimental** (may change in 0.5.x) | no               | `options.items-table.*` beyond `zebra/header-fill/column-order`; `arrange: function`; `options.row` capture; `masthead`/`parties`/`band*` parts; `looks.*` contents                     |
| **Internal**                           | no               | every other ctx key (`ctx.global`, `ctx.item-data`, ...), `token-spec`, the generic `render-table` params                                                                               |

### 5.4 Where compliance-critical output lives

| Output                                                         | Lives in                                                                                                                               | Why a theme cannot silently lose it                                                                                                                        |
| -------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------- |
| PDF metadata (`title/author/date/keywords` incl. ZUGFeRD)      | `root.draw`, before `render-frame`                                                                                                     | runs before any theme code. `set document` is illegal inside containers, and every part runs inside one (verified: blank/modern/custom all carry metadata) |
| `text.lang`/`region`                                           | `root.draw` (+ **bug fix**: `lang` from `locale.strings.meta.lang`)                                                                    | frame text rules never set `lang`. Verified: fr-fr prints "Page 2 sur 2"                                                                                   |
| ZUGFeRD XML attachment                                         | `root.draw` (`pdf.attach`)                                                                                                             | parts are draw-only and receive no data path to measure. Verified for din/modern/ch under `--pdf-standard a-3b`                                            |
| Which legal notices are required                               | component _measure_ (view v2 `notices`, `required`)                                                                                    | the renderer only styles. `notices` is its own part: replacing `items-table` or `totals` can no longer drop it                                             |
| Legal notices rendered at all                                  | `notices` is a **compliance part**: `none` is rejected at resolve time, and an empty result while `required` is a panic at render time | verified e3, e11                                                                                                                                           |
| Zero-tax row suppression                                       | measure (`view.taxes` pre-filtered)                                                                                                    | a custom `totals` only sees rows it must show                                                                                                              |
| EPC-QR payload (EUR only, amount threshold, text vs reference) | `bank-details` measure builds `view.qr` (content, black on white, min size clamped to 20 mm)                                           | parts can place or scale it but never build it. `qr-size` below the floor is clamped                                                                       |
| Swiss QR-bill (future)                                         | its own component, rendered inside an `isolate: true` region reserved by the layout                                                    | brand-immune scope resets font/colour and tokens (verified by the placeholder slip: Liberation Sans, black)                                                |
| Address window content                                         | `recipient` part inside a fixed first-page region (tagged, reading order)                                                              | layouts may move the window; min font sizes are validated from the tokens (`size.fine >= 6pt`), proposal 8                                                 |

---

## 6. Page frame & arbitrary formats

**The frame** (`theming/frame.typ`, ~260 lines) replaces letter-pro in the render path. It issues
**one unconditional top-level `set page(..)`** (the dead-header bug came from `set page` inside
`if`). It computes paper dimensions (`a4`, `a5`, `us-letter`, `us-legal`, or `(width:, height:)`),
resolves each region's rectangle (`x | right`, `y | bottom`, relative sizes), and renders:

1. `background` layer: stationery for page 1 or later pages, plus background regions (marks, band, rail).
2. First-page `fixed` regions: `place()`d **in flow**, so they are tagged and read in region order.
3. A spacer to `body-top` (`auto` = below the lowest reserving region + `body-gap`).
4. `before` regions (reference line, title, masthead ...), then the **body** (`par(justify)`), then
   `after` regions. `float: true` reserves only the part inside the text area and extends to the
   paper edge. If it does not fit, it moves to the next page (verified both ways for the QR-bill slip).
5. `header`/`footer` regions per page kind, via `context` + `here()` / `counter(page).final()`.
   Parts get `view.page`.
6. `foreground` layer: foreground regions plus fixed regions for other page sets (stamps, "KOPIE";
   verified on 2 pages).

**Requirements mapping:**

- **Paper & margins** (R9): `paper`, `flipped`, `margin`. Per-page margins are impossible in Typst,
  so page 1 differs through `body-top`.
- **Address window geometry** (R10): the `address` region. National presets are data; a
  company-specific window is one `region("address", x: .., y: ..)` patch.
- **Information block**: the `info` region hosting `info-block` (label/value list from references)
  or `sender-extra`.
- **Marks** (R12): `layout.marks` geometry + a `marks` background region. `marks(none)` = digital.
- **First vs following pages** (R13, R17): the `pages` selector on every region. The DIN preset
  ships a `continuation` header (`pages: "rest"`: sender · subject · page x/y).
- **Localized page numbering** (R16): the `page-number` part reads the proposed locale key
  `strings.document.page-of: (current, total) => content` (the prototype uses a fallback table
  de/en/fr/it/es). `options.page-number.format` overrides it and `.from` sets the first numbered page.
- **Pre-printed** (R14): `stationery("pre-printed")` drops `brand: true` regions and keeps all geometry
  (verified). Digital twin: `stationery((first: image("lh-1.svg"), rest: image("lh-2.svg")))`.
  E-invoice: `"generated"`. One switch, drivable from `sys.inputs`.
- **Reserved zones** (R18): `place: "after", float: true, isolate: true, pages: "last"` + `height`.
  The footer on that page is turned off with `pages: "not-last"` (sn-010130 preset).
- **Multi-column legal footer (#18)**: the `legal-footer` part renders columns (company | contact
  | register, management, VAT, tax number | bank) from sender data, with locale labels, on **every
  page** (`pages: "all"`). Users compose their own footer the way #18 asks (predefined blocks +
  free content), because region `parts` accept part names, content _and_ functions:
  ```typst
  region("legal", place: "footer", pages: "all", arrange: (columns: (1fr, 1fr, auto)),
    parts: ("legal-footer", [Geschäftsführung: Erika Muster], (ctx, v) => [HRB 12345]))
  ```

**Defining a completely new format without forking** (verified with the A5 sidebar receipt):
write a layout dict (3.8), optionally add parts, and pass `themes.blank.with(layout: my-layout,
(parts: (my-part: (ctx, view) => ..)))`. No invoice-pro file changes.

**Third-party theme package on Typst Universe.** The version-bound loom key
(`<invoice-pro:0.4.2>`) means motifs created by another invoice-pro version are _silently ignored_.
Hence the rule: **theme packages ship data and plain functions only, and ideally do not import
invoice-pro at all.** Layouts are dicts, parts are `(ctx, view) => content` and read everything from
`ctx`/`view` (no `info.*`), and patches are dicts in patch shape. The running invoice-pro injects
its base, merges and validates. Verified with a local package `@local/acme-theme:0.1.0` that has
zero invoice-pro imports:

```typst
// acme-theme/lib.typ (third party)
#let sidebar-a5 = (..)                          // layout dict (3.8)
#let rail(ctx, view) = block(fill: ctx.theme.tokens.color.primary, ..)
#let patch = (parts: (acme-rail: rail, acme-head: head),
              tokens: (color: (primary: rgb("#7c3aed")), size: (base: 9pt)),
              options: (items-table: (zebra: (none, none))))
// user
#import "@preview/acme-theme:0.1.0" as acme
#show: invoice.with(theme: themes.blank.with(acme.patch, layout: acme.sidebar-a5))
```

A package that wants to be a ready-made theme can also export
`#let theme = (..patches, base: auto) => ..` built with the user's `themes.build`.
The recommended pattern is data + `themes.blank.with(..)`, because it needs no import.

---

## 7. Walkthroughs

**(1) Freelancer, digital-only, five minutes**

```typst
#show: invoice.with(
  theme: themes.din-5008.with({
    import themes.custom: *
    logo(image("logo.svg", alt: "Studio Lina Berg"), height: 12mm)
    colors(primary: rgb("#0f766e"))          // on-primary derived
    fonts(body: ("Inter", "Liberation Sans"))
    marks(none)                              // digital only
  }),
  locale: locale.de-de, tax-exempt-small-biz: true, ..
)
```

**(2) GmbH: pre-printed + digital twin + ZUGFeRD, § 35a footer**

```typst
#let mode = sys.inputs.at("output", default: "pdf")        // print | pdf | einvoice
#let acme = { import themes.custom: *
  logo(image("acme.svg", alt: "ACME Maschinenbau GmbH")); colors(primary: rgb("#003a70")) }
#show: invoice.with(
  theme: themes.din-5008.with(acme, layout: layouts.din-5008-b, {
    import themes.custom: *
    stationery(if mode == "print" { "pre-printed" }
      else if mode == "pdf" { (first: image("lh-1.svg"), rest: image("lh-2.svg")) }
      else { "generated" })                                   // SVG: PDF/A-3b safe
    if mode != "print" { marks(none) }
  }),
  sender: (name: "ACME Maschinenbau GmbH", .., register: [Amtsgericht Stuttgart HRB 12345],
           management: [GF: Dr. Erika Muster, Max Beispiel], vat-id: "DE123456789"),
  zugferd: if mode == "einvoice" { "en16931" },
)
```

The `legal` footer region is `brand: true`, so pre-printed paper drops it; `pages: "all"` prints it on
every page otherwise. (A background letterhead suppresses brand regions too, because it is not
"generated". Override per region with `region("legal", brand: false)` if the SVG has no footer.)

**(3) Swiss SME: right window, QR-bill**

```typst
#show: invoice.with(
  locale: locale.de-ch,
  theme: themes.din-5008.with(layout: layouts.sn-010130-right, {
    import themes.custom: *
    logo(image("logo.svg", alt: "Treuhand Aare AG")); colors(primary: rgb("#7a1f2b"))
    fonts(body: ("Source Serif 4", "Libertinus Serif"))    // slip stays Liberation Sans (isolate)
    // left-window envelopes instead: region("address", right: auto, x: 22mm)
  }), ..)
#line-items[..]
#qr-bill(..)   // future component; the layout already reserves 210 x 105 mm on the last page
```

(With `right:` anchoring, moving the window means `region("address", x: 22mm, right: auto)`; the
validator rejects setting both.)

**(4) Agency, white-label, TOML brands**

```typst
#let entity = toml("brands/" + job.brand + ".toml")
#let brand = (tokens: (color: (primary: rgb(entity.brand.primary)),
                       font: (body: entity.brand.fonts)),
              options: (logo: (image: image("brands/" + entity.brand.logo, alt: entity.brand.name))))
#show: invoice.with(theme: themes.modern.with(brand), sender: entity.sender, ..job.header)
```

The brand _is_ a patch dict, so TOML key typos surface as `theme::tokens::color has unknown key ...`.
Lengths from files go through a small `themes.parse-length("10.5pt")` regex helper (specified, not
prototyped). The user calls `image()`, because packages cannot open user paths on 0.14.

**(5) SaaS batch pipeline**

```typst
// theme.typ (versioned, shared)
#let company-theme = themes.modern.with(json("brand.json"))    // pure data patch
// invoice.typ
#show: invoice.with(theme: company-theme, locale: locale.at(d.locale), ..d.header)
```

`typst compile --pdf-standard a-3a,ua-1 --font-path fonts ...`. The theme value is immutable and
memoized, and validation panics fail the job early. A layout chosen per region would be
`layout: if d.region == "us" { layouts.us-letter-10 } else { layouts.din-5008-a }`. Deliberately
explicit; section 11 covers why the region is not inferred.

**(6) Design studio: Stripe-like band with DIN window, custom payment block**

```typst
#show: invoice.with(theme: themes.band.with({
  import themes.custom: *
  colors(primary: rgb("#111827")); fonts(body: "Inter", heading: "Fraunces")
  options("items-table", zebra: (none, none), header-fill: t => t.color.primary)
  options("totals", width: 45%)
  part("payment-terms", (ctx, view) => block(fill: ctx.theme.tokens.color.surface, inset: 1em,
    text(size: 1.3em)[Due: *#view.total.text*]))
}))
```

**(7) Accessibility-bound supplier**

```typst
#show: invoice.with(theme: themes.din-5008.with({
  import themes.custom: *
  logo(image("stadtwerke.svg", alt: "Stadtwerke Musterstadt"))
  colors(primary: rgb("#00843d"))
  options("accessibility", min-contrast: 4.5)   // proposed: panic below AA (section 8)
  marks(none)
}))
```

Metadata and `lang` come from core; the address is tagged in reading order; running furniture is
an artifact. Built-in themes are CI-compiled under `a-3a,ua-1`.

**(8) US subsidiary, Letter + #10**

```typst
#import "corporate.typ": corporate-brand                   // same patch as the German parent
#show: invoice.with(locale: locale.en-us,
  theme: themes.din-5008.with(corporate-brand, layout: layouts.us-letter-10,
    themes.custom.region("remit", place: "footer", pages: "all",
      parts: ([*Remit to:* ACME Inc., PO Box 12, Austin TX], [billing\@acme.com]), arrange: "row")))
```

**(9) Third-party theme package author**: see section 6 (a data layout, plain parts, a patch dict,
no invoice-pro import, users write `themes.blank.with(pkg.patch, layout: pkg.layout)`).

**(10) Scoped style for one subtree**

```typst
#line-items[
  #group([Phase 1])[..]
  #themed(themes.custom.options("row", fill: rgb("#dcfce7")))[
    #group([Phase 2 — optional])[..]                 // highlighted: header, items, subtotal
  ]
]
#themed({ import themes.custom: *; colors(primary: rgb("#1d4ed8"))
  wrap("bank-details", (ctx, view, inner) => block(fill: ctx.theme.tokens.color.surface, inset: 8pt, inner(ctx, view))) })[
  #bank-details(..)
]
```

---

## 8. Validation & error messages

**When.**
(a) Helper call time: Typst's own `unexpected argument`.
(b) `invoice()`, once: patch groups, closed keys (tokens tree, options per part, layout, margin,
region fields), region semantics (place, pages, anchors), part references, and part types.
(c) `themed` scope: the same checks, plus layout patches rejected.
(d) Render time: a compliance part returning nothing while `required`.

**House style**: path `theme::<group>::<key>`, the offending value, the allowed set. Loom's
matcher only returns a bool, so the path-tracking walker is ours. All messages below are **real
output** of `tests/errors/*.typ`:

```
theme::tokens::color has unknown key `primry`. Allowed keys: primary, on-primary, text, muted, subtle, rule, surface, negative, positive, label
theme patch has unknown group `colour`. Allowed groups: layout, parts, options, tokens, meta
theme::layout::regions::letterhead::parts references unknown part `logoo`. Known parts: logo, sender, sender-extra, ...
theme::layout::regions::info has unknown key `colour`. Allowed keys: place, pages, x, y, right, bottom, width, height, parts, arrange, gap, align, inset, fill, stroke, brand, isolate, float, reserve, text
theme::layout::regions::legal::place ("bottom") must be one of "fixed" | "before" | "after" | "header" | "footer" | "background" | "foreground"
theme::layout::regions::stamp needs exactly one of `x` or `right` (place: "fixed")
theme::parts::notices carries legally required output and cannot be `none`; wrap it or replace it with a renderer instead
theme::parts::notices returned no content although legally required output is present
themed: layout patches are document-level; pass them to `invoice(theme: ..)` instead
unexpected argument: primry                       (themes.custom.colors(primry: red))
theme::layout::paper `b5` has no known size; use (width:, height:) for custom paper. Known: a4, a5, us-letter, us-legal
```

**Unknown keys**: always an error in closed dicts. Open by design: `regions` names, `parts` names,
`options.custom`. Custom names are still checked for _references_ (a region naming a missing part
fails).

**Low contrast** (proposed, helpers verified): Typst has no warning API, so the choice is
panic or nothing. `options.accessibility.min-contrast: none | float` (default `none`; the built-in
presets are CI-checked at 4.5). When set, resolve-time checks run on `on-primary`/`primary`,
`muted`/white, `muted`/`surface`, `negative`/white, and each failure gives e.g.
`theme::tokens::color::muted (#9ca3af) has contrast 2.54:1 on #ffffff, below min-contrast 4.5`.
`on-primary: auto` never fails, because it is chosen by contrast.

**PDF/A** (proposed): `invoice` knows `zugferd`. If it is set and `stationery.first/rest` or
`options.logo.image` is an `image` element whose `format`/`source` ends in `pdf`, the panic is
`theme::layout::stationery: PDF images cannot be embedded under PDF/A-3 (ZUGFeRD); convert the
letterhead to SVG`. `cmyk` token colours with `zugferd` get a matching panic. Neither is prototyped.

**Address zone minimum**: `tokens.size.fine < 6pt` panics
`theme::tokens::size::fine (5pt) is below the DIN 5008 minimum of 6pt for the return-address line`.

---

## 9. Internals sketch

**Plumbing.**

```
invoice(theme:)                                      src/invoice.typ
  eval-theme = validate-theme(type(theme) == function ? theme(base: base-theme) : theme)
  inputs.theme = eval-theme                          ONE ctx key: theme = (meta, layout, parts, options, tokens, token-spec)
  weave(max-passes: 2, ..)
root.scope   ensure("lang", from locale.strings.meta.lang)         (bug fix)
root.draw    set text(lang, region)  ·  normalize references  ·  pdf.attach(factur-x)
             set document(title, author, date, keywords)             (moved out of the theme)
             render-frame(ctx, body)                                 src/theming/frame.typ
components   draw: call-part(ctx, "<part>", view)                    src/theming/parts/body.typ
             (no more nest("theme", ensure(slot, panic)) per component: parts always exist in base)
themed       compute-motif scope: ctx.theme = scope-theme(ctx.theme, patches)
group        measure records ctx.theme.options.row -> signal.style -> view entry.style
```

**How built-in renderers read tokens.** `ctx.theme.tokens.<role>` and `ctx.theme.options.<own-part>`
only. In the prototype the ~50-parameter generic `render-table`/`render-totals` are wrapped by
`items-table`/`totals` parts that map tokens once. The 4-layer hand plumbing and the five
duplicate default sets go away: defaults exist once in `schema.typ`. Milestone M4 folds
`render-table`'s parameters into options reads directly.

**File layout** (prototype = proposal):

```
src/theming/
  schema.typ      base-layout, region-defaults, base-tokens, base-options, base-meta   (defaults ONCE)
  merge.typ       merge, wrap-marker, replace-marker, flatten-patches
  tokens.typ      derive-tokens, contrast, on-color
  validate.typ    validate-theme, compliance-parts, path-style messages
  build.typ       base-theme, apply-patch, build, finalize, scope-theme
  custom.typ      the patch DSL (themes.custom)
  layouts.typ     page-master presets (data)
  presets.typ     looks + theme presets
  frame.typ       render-frame, region-rect, page-matches, frame-view
  scope.typ       themed
  parts/frame.typ default frame parts
  parts/body.typ  default body parts + call-part
src/public/themes.typ, src/public/layouts.typ     curated facades
(removed) src/themes/DIN-5008, src/themes/base-theme/base.typ, blank, @preview/letter-pro import
```

**Performance.** One nested `theme` key (cheaper than flat keys). Defaults are resolved once
before weave, never per node. `themed` costs one merge per scope per pass. Frame parts run once
(flow) or once per page (running regions; small closures). Region lists are filtered once per frame.
Measured overhead: section 4.4.

**loom 0.1.1 as-is.** It works unchanged. Only public API is used (`compute-motif`, ctx
inheritance, `intertwine` via the existing `eval-content` for user content with `info.*` in
regions). **loom nice-to-haves:**

1. A deep `apply` / `merge-deep` scope motif upstream.
2. An optional _secondary_ version-independent motif key, so third-party packages could emit
   `info.*` safely.
3. `ensure` distinguishing missing from `none`.
4. The labelled-container crash fix (would allow `show <label>` hooks on user blocks).
5. Export `matcher.display` and an `optional()` descriptor with path-reporting `match`.
6. The `observer` typo fix.

**Compiler.** Everything used exists in 0.14 (no `dictionary.map/filter`, no `path()`). The
prototype was compiled on 0.15.1 only. **I do not recommend bumping the minimum.** Brand files keep
"user passes the dict and `image()`" instead of `path()`. A CI job on 0.14.0 is milestone M1.

---

## 10. Feasibility evidence

Prototype: `<session>/proto-structure-first/`

| File                                                                                                                                                                        | Verifies                                                                                                                                                                                                                                            |
| --------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `src/theming/*.typ`, `src/theming/parts/*.typ`                                                                                                                              | the engine: merge / wrap / derive / validate / frame / DSL / scope (~1,300 lines)                                                                                                                                                                   |
| `src/invoice.typ`, `src/components/root.typ`, `bank-details/payment-goal/signature/line-items.typ`, `group.typ`, `logic/tree.typ`, `themes/components/line-items/table.typ` | minimal rewiring: `call-part`, core metadata, lang fix, row-style capture                                                                                                                                                                           |
| `tests/demo.typ` (`--input fmt=din\|din-b\|ch\|us\|fr\|uk\|modern\|band\|preprinted`)                                                                                       | **ONE unchanged invoice body in 9 formats** -> `tests/out-<fmt>-*.png`; overview `tests/contact-sheet.png` (12 formats)                                                                                                                             |
| `tests/ch-short.typ` -> `out-chshort-1.png`                                                                                                                                 | QR-bill zone floats to the paper's bottom edge on the _same_ page when it fits; `demo.typ --input fmt=ch` shows it moving to page 2 when not                                                                                                        |
| `tests/scoped.typ` -> `out-scoped-1/2.png`                                                                                                                                  | `themed` over `line-items` (tokens + lazy option), over `bank-details` (wrap), nested `themed` replacing `signature`, and back to default outside; document-level `wrap("totals")` + scoped colour; continuation header + "Page 2 sur 2" (lang fix) |
| `tests/group-scope.typ` -> `out-group-1.png`                                                                                                                                | persona 10: one highlighted group via a scope captured in data motifs                                                                                                                                                                               |
| `tests/third-party.typ` + `tests/pkgs/local/acme-theme/0.1.0`                                                                                                               | a third-party package with **no invoice-pro import** ships a new A5-landscape layout + parts (`--package-path tests/pkgs`)                                                                                                                          |
| `tests/fixed-all.typ` -> `out-fixedall-*.png`                                                                                                                               | fixed overlay region on every page (stamp), not reserving body space                                                                                                                                                                                |
| `tests/smoke-new.typ` vs `proto/smoke/test.typ`                                                                                                                             | same invoice old/new: timing (4.4), zebra via options                                                                                                                                                                                               |
| `tests/errors/e1..e11*.typ`                                                                                                                                                 | every message in section 8                                                                                                                                                                                                                          |
| `tests/demo-zugferd.typ` -> `tests/zugferd-{din,modern,ch}.pdf`                                                                                                             | `--pdf-standard a-3b` + `factur-x.xml` + `/AFRelationship /Alternative` + ZUGFeRD keywords in all layouts                                                                                                                                           |
| `tests/pdf-{din,modern,ch,band}.pdf`                                                                                                                                        | compile clean under `a-3b`, `ua-1`, `a-3a,ua-1`                                                                                                                                                                                                     |
| `tests/blank-ua.typ` -> `blank-ua.pdf`                                                                                                                                      | `themes.blank` (no regions at all) now passes `--pdf-standard ua-1` (it failed with "missing document title" before), because metadata is set by core                                                                                               |
| `tests/errors/e12-paper.typ`                                                                                                                                                | unknown-paper message                                                                                                                                                                                                                               |

**Verified.** Cascade end-to-end (base -> preset -> named `layout:` -> block patches -> nested
`themed`); the called and uncalled forms; wrap composition across layers; `none` removal of regions
(`qr-bill: none` in `nf-z-11-001`); `right`/`bottom` anchoring; first/rest/last/not-last selectors;
`stationery("pre-printed")` keeping geometry; the float reserve zone; brand-immune isolation;
localized page labels; metadata/lang/XML in core; strict validation with path messages; data motifs
capturing a scoped style; about 7% overhead.

**Failed, not done, or caveats.**

- Not compiled on 0.14.0.
- The Swiss slip is a placeholder part, not a QR-bill.
- View v2 (raw + formatted) is specified; the prototype adapts the v1 line-items view.
- Contrast/PDF-image guards are specified (helpers verified), not wired.
- The inherited table renderer still draws the "(net)" suffix in a fixed grey (unreadable on dark
  header fills, visible in `out-band-1.png`); that is an existing defect that M4 fixes by reading
  `on-primary`.
- Missing party data still prints placeholder strings like `#sender.city` (existing R14); the frame
  view should carry `none`.
- An early float attempt reserved the full 105 mm plus a margin offset and wrongly pushed the slip
  to page 2; fixed by reserving `height - (margin.bottom - edge)` and placing the region out of flow
  inside the reserve block.
- The first z-order design put page-1 "all" overlays under the body. Fixed by the rule "only
  `pages: "first"` fixed regions are in flow; every other fixed region is foreground".

---

## 11. Trade-offs, risks & rejected alternatives

**Weaknesses.**

- **Geometry is absolute.** Fixed regions do not know their content height. An oversized sender
  block overflows its rectangle, as letter-pro's did. Mitigation: `height: auto` is allowed. For
  flowing furniture, use `before` regions.
- **More concepts than "a theme with knobs".** region, part, look, token, option. The ladder hides
  this: level 1 users only touch `logo`/`colors`/`fonts`; regions appear at level 2-3.
- **The DIN default look changes slightly.** The sender extras move from the overflowing 5.5 cm
  sender block into the info block, and there is a legal footer and a continuation header. That
  costs ~20 visual refs (acceptable under decision 1; the research shows a pixel-identical default
  is cheaper, but it is not required).
- **Per-page margins are impossible** in Typst. A first-page footer taller than later pages needs
  `margin.bottom` sized for the largest.
- **Scoped styles reach data motifs only through capture** (`options.row`). Each new capturable
  style is a small measure change. Kept to one dict to bound cost.
- **Frame parts get the whole frame view.** It is simple and custom-part friendly, but it
  broadens the frozen surface. Mitigation: the frame view is small and documented key by key.
- Brand-immune `isolate` resets to Liberation Sans, which may be missing on a machine. The Swiss
  rules allow Arial/Helvetica/Frutiger, so a fallback list would be one line.

**Deliberately left out.**

- Region inference from locale (R11). It creates a hidden locale -> theme coupling and surprises
  Swiss companies that use left windows. Instead, one explicit `layout:` argument, plus a docs table
  "region -> recommended layout". A future `layouts.for-region(region)` helper can be added without
  breaking anything.
- A DTCG importer (R7): an adapter is possible because a brand is just a patch.
- Carry-over subtotals (R21).
- elembic, valkyrie.
- Label show-rule hooks as the primary API (they stay an escape hatch for draw output).

**Rejected alternatives.**

1. _Keep letter-pro and pass options through_: impossible for background, all-page footer,
   paper, windows and page labels without upstream changes to a third-party package.
2. _Layouts as functions_ (`layouts.din-5008(form: "B")`): mixes conventions again. Layouts are
   data, and variants are separate presets or a `derive`.
3. _Theme as flat slot dict_ (status quo): no geometry axis, whole-slot replacement loses
   compliance output.
4. _Cetz-style implicit same-key inheritance_: magic. Explicit `auto`-derivation and lazy
   `t => ..` references do the same work visibly.
5. _Regions as positioned `grid` templates_ (CSS grid areas): elegant for flow layouts but cannot
   express page-absolute windows and page selectors.
6. _Per-part token namespaces_ (MUI `components.X.styleOverrides`): would multiply frozen keys.
   Options stay per-part but small; everything else goes through wrap/replace.

**Experimental in 0.5.0**: `arrange` functions, `options.row` capture, the
`masthead`/`parties`/`band` parts, `looks` contents, and `options.items-table` beyond the three
frozen knobs.

---

## 12. Implementation roadmap (solo maintainer, each milestone shippable)

| M                               | Scope                                                                                                                                                                                                                                             | Ships                                                                         | Tests                                                                                                                                                               |
| ------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **M1 Core hygiene** (1 weekend) | `lang` fix; `set document` + `pdf.attach` in root; 0.14.0 CI job                                                                                                                                                                                  | alone, as 0.4.3 (fixes "Seite x von y" and blank's missing metadata)          | integration `pg-lang-fr` (visual), `ua-blank` compile under `ua-1`                                                                                                  |
| **M2 Engine**                   | `schema/merge/tokens/validate/build/custom`, `themed`; parts registry = today's 5 slots wrapped as parts; frame = a thin shim that still calls the old DIN document                                                                               | 0.5.0-dev: new theme argument, old look                                       | unit: merge rules (auto/none/array/wrap/replace), derive, every error message (`tests/unit/theme-errors/` compile-fail tests), block-DSL docs test (the I-1 lesson) |
| **M3 Frame**                    | `frame.typ` + `layouts.din-5008-a/b` + frame parts; delete letter-pro; view v2 for bank/payment/signature (raw + formatted, `view.qr` from measure)                                                                                               | first release with running footer (#18), continuation header, marks from data | visual refs `tests/integration/layout-din-a`, `-din-b`, `-preprinted`, `-footer-all-pages`; ZUGFeRD a-3b validation in `check-pr`                                   |
| **M4 Line items**               | split `line-items` into `items-table`/`totals`/`notices`; legal decisions to measure (`view.notices`, `required`, pre-filtered `taxes`); table reads tokens/options directly (drops 50 params, fixes suffix colour, spacer-column and crash bugs) | 0.5.0                                                                         | re-point `issue-39`/`issue-41` tests to public `wrap("totals")`; `tax-exemption-grounds` asserts on `view.notices`; compliance-part panics                          |
| **M5 Formats**                  | `sn-010130-right/left`, `nf-z-11-001`, `uk-c5`, `us-letter-10`, `modern`, `band`; `looks`; the `options.row` scope capture                                                                                                                        | 0.5.0 (layouts are pure data, each is one PR + one ref)                       | one `tests/docs/api-layout-<name>/` visual test per preset, same body file (as `demo.typ`)                                                                          |
| **M6 Docs & lock**              | `docs/api-reference/theme/{index,layouts,parts,custom,base}.md` (locale trio + layouts + parts); registry entries; "publish your own theme package" guide with the no-import pattern; mark stability tiers                                        | tag 0.5.0 = API lock                                                          | every snippet registered in DOCUMENTATION.md/TESTING.md with a tytanic test; thumbnail regenerated                                                                  |
| later                           | contrast/PDF-image guards, `parse-length`, `layouts.for-region`, QR-bill component in an isolated region, document kinds (`view.document.kind`)                                                                                                   | 0.5.x/0.6                                                                     |                                                                                                                                                                     |

Order rationale: M1 has value alone. M2 lands the API shape without visual churn. M3 is the only
big visual diff (refs updated per case, never blanket). M4 fixes the known line-item crashes as
part of the part split. M5 is pure data and can be contributed by users (e.g. PR #40's UK
support becomes a layout).
