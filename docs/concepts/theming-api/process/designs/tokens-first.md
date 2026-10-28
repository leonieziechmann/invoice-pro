# Theming API v0.5.0: "tokens-first"

> **Lens:** a theme is _data_. It is a tiered token tree (reference, then semantic, then component) plus a geometry profile. The tree is resolved once, sealed, and read by 100% token-driven built-in renderers. Render functions exist, but you only reach for them last.
>
> **Prototype:** `scratchpad/proto-tokens-first/` compiles end to end on typst 0.15.1. It produces three formats from one invoice body, a scoped override on one table group, and region-derived geometry. It also ships a TOML brand file, pre-printed mode, PDF/A-3b with ZUGFeRD, PDF/UA-1, and 12 validation paths. Details are in section 10.

---

## 1. Pitch & mental model

A business describes its invoice the way a designer describes a brand. There are one or two colours, a font, a logo, a paper format and an envelope window. After that come a few opinions ("bold totals, no zebra, footer on every page"). With **tokens-first** they write exactly that, as data. In this API the theme _is_ the data: a nested dictionary of named design decisions (_tokens_).

Tokens reference each other through aliases (`"{color.primary}"`) or small derivation descriptors (`tint("{color.primary}", 88%)`, `on("{table.header-fill}")`, `legible(fg, bg)`). Change one seed colour and the zebra stripe, header fill, header text contrast, label colour and group fill all re-derive, accessibly. Page layout is data too: a `geometry` group with paper, margins, window rectangle, info block, fold marks and header zone height. DIN 5008 A is therefore just `themes.geometry.din-5008-a`, one dictionary next to `sn-010130-right`, `nf-z-11-001`, `us-letter-10` and `a4-digital`. It is picked from the locale region unless you say otherwise.

`invoice()` folds all patches onto the package's base schema, resolves every alias once, validates the result and seals it into `ctx.theme`. From then on every built-in part (letterhead, window address, info block, title, table, totals, notes, bank block, payment sentence, signature, footer, continuation header, marks, background, stamp) only _reads_ tokens. Most businesses never write a render function. When they must, a part override receives the built-in as `super`, so wrapping beats ejecting. Compliance output (legal notes, EPC-QR payload, PDF metadata, language, ZUGFeRD) lives in core, outside any part.

```
                          ONE resolution, then read-only
 ┌─────────────── patches, folded left→right (strict deep merge) ───────────────┐
 │ L0 base schema   L1 style preset   L2 geometry      L3 user patches          │
 │ (package, the    themes.classic/   profile          .with(brand(..),         │
 │  running version modern/minimal/   "regional"→ by   table(..), toml data,    │
 │  injects it)     blank             env.region       dotted keys, parts)      │
 └──────────────────────────────────────┬───────────────────────────────────────┘
                                        ▼
        resolve aliases "{a.b}" + "$op" descriptors (+ env: region, lang, zugferd)
                                        ▼
   validate (unknown keys, types, mandatory parts, logo alt, contrast lints/strict)
                                        ▼
        ctx.theme = (kind, name, env, lints, sealed: metadata((source, tokens)))
                 │                                    │
       L4 restyle(..)[subtree]                        │ read-only
       merge onto `source`, re-resolve                ▼
                 │           ┌─────────────── token tree ────────────────────┐
                 └─────────► │ ref.*      seeds & scales (brand, ink, type,  │
                             │            space, stroke)                     │
                             │ color.* font.* size.* weight.* space.*        │
                             │ stroke.*   (semantic roles)                   │
                             │ letterhead.* address.* references.* title.*   │
                             │ table.* totals.* notes.* bank.* payment.*     │
                             │ footer.* page-number.* continuation.*         │
                             │ marks.* ... (component)                       │
                             │ geometry.* (paper, margin, window, info,      │
                             │ header, marks, references style)              │
                             │ assets.*   (logo content, alt)                │
                             │ parts.*    (auto | none | (ctx, view,         │
                             │            super:) => content)                │
                             └───────────────────────────────────────────────┘
                                        ▼
    CORE frame (owns set page)  ──►  parts read tokens  ──►  CORE compliance
    geometry → zones, marks,         letterhead, address,    set document, text.lang,
    header/footer/background         info, title, table,     ZUGFeRD attach, legal
                                     totals, bank, ...       notes, EPC-QR payload
    L5 explicit component args (e.g. bank-details(qr-code: ..)) win over tokens
```

The design has three orthogonal axes, and each one is a patch: **style** (`classic` / `modern` / `minimal` / `blank`), **geometry** (`din-5008-a` ... `a4-digital`) and **brand** (seeds, fonts, logo). Any combination works, so you can have classic on US Letter, modern on DIN B, or the default look on the Swiss right window.

---

## 2. Public API surface

### 2.1 How it is passed to `invoice()`

```typst
#show: invoice.with(
  theme: themes.classic,                 // preset, passed UNCALLED (like locale.de-de)
  theme: themes.modern.with(..patches),  // customise with .with (later patch wins)
  theme: toml("brand.toml"),             // raw patch dict/array -> applied onto themes.classic
)
```

**Calling convention.** Presets are uncalled functions `(..patches, base: none, env: none) => theme`, exactly the locale shape (`src/locale/factory.typ:37-38`). They are customised with `.with(...)`, the package's one customisation verb. `invoice()` injects the _running_ version's schema as `base:` and the environment as `env:`. This gives the locale API's forward-compatibility promise (`locale/custom.md:14`): a theme written for 0.5 gains any tokens added in 0.6 for free.

Two deliberate improvements over the locale shape:

- `base` and `env` are **named**. If a user writes `themes.classic()`, `base` is `none`, and the preset panics with an actionable message instead of silently degrading. This fixes footgun I-5 / E10.
- `invoice()` also accepts a **dictionary or array**, which is applied as a patch onto `themes.classic`. This is what makes "theme = data" literal: `theme: toml("brand.toml")` and `theme: json(sys.inputs.brand)` work directly.

After evaluation `invoice()` asserts `kind == "invoice-pro/theme"`. No malformed value can reach loom's `nest("theme")` and be wiped silently (R3 in component-contract).

### 2.2 Exports

`src/lib.typ` adds two bare verbs next to `apply`: `restyle` and `themed`. The `themes` namespace keeps its plural name, which the README and template already use.

```typst
// src/public/themes.typ  (curated facade, implementation in src/theme/*)
#import "../theme/presets.typ": classic, modern, minimal, blank
#import "../theme/build.typ": build-theme, resolve-theme, tokens-of
#import "../theme/custom.typ" as custom          // patch DSL
#import "../theme/geometry.typ" as geometry      // profiles = data
#import "../theme/engine.typ": replace, derive, tint, shade, mix, on, legible, scale, times, stroke-of, pick
#import "../theme/color.typ": contrast, on-color, ensure-contrast
#import "../theme/data.typ": from-data, from-dtcg   // from-dtcg: experimental
#import "../theme/specimen.typ": specimen
```

#### Presets (style axis, geometry-agnostic)

```typst
/// Today's DIN-5008 look re-expressed as tokens (default of `invoice`).
/// Geometry defaults to "regional" (DIN 5008 A for de/at, SN 010130 right for ch, ...).
/// -> function
#let classic = build-theme(name: "classic", classic-tokens)

/// Brand-coloured header band, boxed bank block, info block instead of reference line.
/// -> function
#let modern = build-theme(name: "modern", modern-tokens)

/// Hairlines, no fills, logo left. "Stripe-like".
/// -> function
#let minimal = build-theme(name: "minimal", minimal-tokens)

/// Neutral tokens, no generated letterhead, no footer, no marks. For data tests
/// and fully custom frames. Unlike today's `blank`, it still emits PDF metadata (core).
/// -> function
#let blank = build-theme(name: "blank", blank-tokens)
```

#### Tier 2: authoring

```typst
/// Builds a publishable theme (mirrors `locale.build-locale`).
/// Patches are folded in order onto the schema that `invoice()` injects.
///
/// -> function
#let build-theme(
  /// Name used in error messages and `themes.specimen`.
  /// -> str
  name: "custom",
  /// Token patches: dictionaries, arrays of dictionaries (DSL output), data-file dicts.
  /// -> dictionary | array
  ..patches,
) = (..user, base: none, env: none) => { ... }

/// Evaluates a theme outside an invoice (tests, docs, third-party CI).
/// Returns the resolved token dictionary.
///
/// -> dictionary
#let resolve-theme(
  /// A theme function, e.g. `themes.classic.with(..)`.
  /// -> function
  theme,
  /// Environment the tokens may depend on.
  /// -> dictionary
  env: (region: "de", lang: "de", zugferd: none, kind: "invoice"),
)
```

#### Patch DSL `themes.custom`

Every helper returns a **one-element array** without `return`, so helpers written one per line in a `{ import themes.custom: * ... }` block join correctly. This fixes the verified locale bug I-1; two `table(..)` calls in one block both apply (verified, `verify/wrap.typ`).

```typst
/// Brand identity. One seed colour is enough; everything else derives.
/// -> array
#let brand(
  /// Primary brand colour (seed 1). -> auto | color
  color: auto,
  /// Secondary colour (seed 2). Defaults to seed 1. -> auto | color
  accent: auto,
  /// Body font family or fallback chain. -> auto | str | array
  font: auto,
  /// Heading font family. -> auto | str | array
  heading-font: auto,
  /// Logo, e.g. `image("logo.svg")` called in the USER's file. -> auto | none | content
  logo: auto,
  /// Alt text; mandatory when `logo` is set (PDF/UA-1). -> auto | str
  logo-alt: auto,
)

/// Selects a geometry profile by name and/or overrides single geometry keys.
/// -> array
#let geometry(
  /// "regional" | "din-5008-a" | "din-5008-b" | "sn-010130-right" | "sn-010130-left"
  /// | "nf-z-11-001" | "uk-c5" | "us-letter-10" | "a4-digital" | "letter-digital" | dictionary
  /// -> auto | str | dictionary
  profile: auto,
  /// Any key of the `geometry` group, e.g. `margin: (top: 30mm)`, `window: none`.
  ..keys,
)

/// One helper per component group. Named keys are validated by the strict merge
/// against the schema, so helpers can never drift from it (lesson I-6).
/// -> array
#let palette(..keys)      // -> color.*
#let typography(..keys)   // -> size.*   (fonts: brand(font:) or tokens("font.body": ..))
#let letterhead(..keys)   #let address(..keys)   #let references(..keys)
#let title(..keys)        #let table(..keys)     #let totals(..keys)
#let notes(..keys)        #let bank(..keys)      #let payment(..keys)
#let signature(..keys)    #let footer(..keys)    #let page-number(..keys)
#let continuation(..keys) #let marks(..keys)
#let background(first: auto, rest: auto)
#let stamp(text)                          // "ENTWURF", "PAID", "STORNO"
#let accessibility(contrast: auto, min-ratio: auto)
/// Raw patch; accepts nested dicts and dotted keys: tokens("table.header-fill": red)
#let tokens(..dicts-or-named)
/// Replace or wrap a part: part("signature", (ctx, view, super: none) => ..)
#let part(name, renderer)
```

#### Derivation constructors (pure data descriptors)

```typst
#let tint(of, amount)        // ("$op": "tint", of: .., amount: ..)   mix towards white (Oklab)
#let shade(of, amount)       // mix towards black
#let mix(a, b, ratio: 50%)
#let on(of)                  // black/white with best WCAG contrast on `of`
#let legible(fg, bg, target: 4.5)   // darken/lighten fg until contrast >= target
#let scale(base, ratio, step)       // modular type scale base * ratio^step
#let times(of, factor)
#let stroke-of(thickness, paint)
#let pick(by, cases, default: none) // e.g. pick("{env.region}", (ch: .., us: ..))
#let derive(fn)              // escape hatch: fn(get) where get("color.primary") -> value
#let replace(value)          // merge verb: replace a group/sides value wholesale
```

These return plain dictionaries tagged with the reserved key `"$op"`, following the DTCG `$` convention. A third-party theme can therefore write them without importing invoice-pro, and a data file can contain them too (`{ "$op" = "tint", of = "{color.primary}", amount = "88%" }`).

#### Body verbs

```typst
/// Applies token patches to a subtree; derived tokens re-derive inside it.
/// Inside `line-items`, groups/items in the subtree record the patch so their rows
/// are styled (row fill, group fill, group text).
/// -> content
#let restyle(..patches, body)

/// Lets custom body content read the resolved tokens of its scope.
/// `#themed(t => block(fill: t.color.surface-alt)[Thank you!])`
/// -> content
#let themed(fn)
```

#### Data and QA

```typst
/// Converts a parsed json/yaml/toml dict into a patch (no eval): "#rrggbb" -> rgb,
/// "10pt"/"25mm"/"0.4em"/"66%" -> length/ratio, "none" -> none, "{a.b}" stays an alias.
/// `assets` supplies content files cannot hold (the logo must be image() in the user's file).
/// -> array
#let from-data(data, assets: (:))

/// EXPERIMENTAL: maps W3C DTCG 2025.10 tokens onto the schema via `map`
/// (dtcg-path -> token path); resolves DTCG aliases, converts px/rem.
/// -> array
#let from-dtcg(data, map: (:), px: 0.75pt)

/// Visual QA: every semantic colour with its contrast ratio, the chosen geometry,
/// and the contrast lints of the theme.
/// -> content
#let specimen(theme, env: (..))
```

---

## 3. Schemas

### 3.1 The base schema (single source of truth, `src/theme/schema.typ`)

Tier rule: `ref` holds seeds and scales, semantic groups alias or derive from `ref`, and component groups alias or derive from semantic tokens. Patches may target any tier. Rebranding means patching `ref`. Tweaking one table means patching `table`.

| Path                                                                                                                        | Type                                              | Default                                                                                       | Meaning                                                                         |
| --------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------- | --------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------- |
| **env.** region / lang / zugferd / kind                                                                                     | str / str / none\|str / str                       | injected                                                                                      | Read-only context; aliases and `pick`/`derive` may use it (R29)                 |
| **ref.color.** brand                                                                                                        | color                                             | `#334155`                                                                                     | Seed 1                                                                          |
| ref.color.accent                                                                                                            | color                                             | `"{ref.color.brand}"`                                                                         | Seed 2                                                                          |
| ref.color.ink / paper / danger                                                                                              | color                                             | black / white / `#b22222`                                                                     | Base inks                                                                       |
| **ref.font.** sans / serif / mono                                                                                           | array\<str>                                       | `("Liberation Sans","Arial","Helvetica")` / `("Libertinus Serif",)` / `("DejaVu Sans Mono",)` | Family chains (fonts cannot be bundled, R35)                                    |
| **ref.type.** base / ratio                                                                                                  | length / float                                    | `10pt` / `1.2`                                                                                | Type scale                                                                      |
| **ref.space.**unit                                                                                                          | length                                            | `0.4em`                                                                                       | Spacing unit                                                                    |
| **ref.stroke.** hairline/thin/regular/thick                                                                                 | length                                            | 0.25/0.5/1/2 pt                                                                               | Stroke scale                                                                    |
| **color.** text                                                                                                             | color                                             | `"{ref.color.ink}"`                                                                           | Body text                                                                       |
| color.text-muted / text-subtle                                                                                              | color                                             | `mix(ink, paper, 55%/40%)`                                                                    | Descriptions, notes / sub-labels                                                |
| color.primary / accent                                                                                                      | color                                             | `"{ref.color.brand}"` / `"{ref.color.accent}"`                                                | Brand roles                                                                     |
| color.on-primary                                                                                                            | color                                             | `on("{color.primary}")`                                                                       | Text on brand fills (auto contrast)                                             |
| color.accent-text                                                                                                           | color                                             | `legible("{color.accent}", paper)`                                                            | Accent usable as text (>= 4.5:1)                                                |
| color.surface / surface-alt                                                                                                 | none\|color                                       | `none` / `tint(primary, 88%)`                                                                 | Block fills / zebra                                                             |
| color.rule / label / negative / positive / mark                                                                             | color                                             | text / `legible(mix(primary,text,30%))` / danger / `mix(ink,paper,20%)` / ink                 | Rules, tax labels, discounts, surcharges, marks                                 |
| **font.** body / heading / numeric                                                                                          | array                                             | `"{ref.font.sans}"` / `"{font.body}"` / `"{font.body}"`                                       | Font roles (R4)                                                                 |
| font.regulated                                                                                                              | array                                             | Liberation Sans, Arial, Helvetica                                                             | Brand-immune zones (QR-bill: only these)                                        |
| font.figures                                                                                                                | str                                               | `"tabular"`                                                                                   | `number-width` in amount columns                                                |
| **size.** body / letter / label / caption                                                                                   | length                                            | `11pt` / `"{ref.type.base}"` / `scale(base, ratio, -1)` / `scale(.., -2)`                     | Body, letterhead/address, reference labels, return line/footer                  |
| size.small / large / heading                                                                                                | relative                                          | `0.85em` / `1.2em` / `1.4em`                                                                  | Descriptions, totals emphasis, title                                            |
| **weight.** strong / regular                                                                                                | str                                               | `"bold"` / `"regular"`                                                                        | Single bold mechanism (fixes S-30)                                              |
| **space.** xs/sm/md/lg                                                                                                      | length                                            | derived from `ref.space.unit`                                                                 | Spacing scale                                                                   |
| **stroke.** hairline/thin/regular/thick                                                                                     | stroke                                            | `stroke-of(ref.stroke.*, "{color.rule}")`                                                     | Paint-carrying strokes (fixes the `table.hline` accident, E13)                  |
| **letterhead.** mode                                                                                                        | enum                                              | `"generated"`                                                                                 | `"generated"` \| `"pre-printed"` \| `"none"` (R14)                              |
| letterhead.arrangement                                                                                                      | enum                                              | `"subject-left"`                                                                              | `"subject-left"` \| `"logo-left"` \| `"band"` \| `"centered"` (R19)             |
| letterhead.fill / text / size / name-weight / logo-height / show-extra                                                      | ..                                                | `none` / text / letter / strong / `14mm` / `true`                                             | Band fill defaults to `color.primary`                                           |
| **address.** return-line / return-size / size / label / label-fill                                                          | bool/len/len/none\|str/color                      | `true` / caption / letter / `none` / muted                                                    | Window and flow address ("Bill to")                                             |
| **references.** label-size / value-size / label-fill / gutter                                                               | ..                                                | label / letter / text / `12pt`                                                                | Reference line or info block                                                    |
| **title.** size / weight / fill / show-date / date-weight                                                                   | ..                                                | heading / strong / text / `true` / strong                                                     | Subject + "City, **date**" row                                                  |
| **body.** justify / hyphenate                                                                                               | bool                                              | `true` / `true`                                                                               | Body paragraphs                                                                 |
| **table.** header-fill / header-text / header-weight / header-suffix-fill                                                   | ..                                                | `none` / text / strong / `derive(readable on fill)`                                           | Header band; suffix readable on any fill (fixes E6a/E17 tax suffix)             |
| table.header-rule-top / header-rule-bottom / rule-bottom                                                                    | stroke\|none                                      | regular / thin / regular                                                                      | Rule rhythm                                                                     |
| table.header-inset / row-inset / cell-inset                                                                                 | sides                                             | `(x: .4em, y: .6em)` / `.3em` / `.4em`                                                        | **Fold** partial dicts (fixes S-25)                                             |
| table.row-fill-odd / row-fill-even                                                                                          | none\|color\|array\|function                      | `none` / `"{color.surface-alt}"`                                                              | Typst-native fill semantics (#33)                                               |
| table.row-stroke / header-repeat / tax-suffix                                                                               | ..                                                | `none` / `true` / `"newline"`                                                                 |                                                                                 |
| table.description-fill / subtitle-fill / small                                                                              | ..                                                | muted / subtle / small                                                                        |                                                                                 |
| table.group-fill / group-text                                                                                               | none\|color / color                               | `none` / text                                                                                 | Group header/subtotal rows (new hook)                                           |
| table.discount / surcharge                                                                                                  | color                                             | negative / positive                                                                           |                                                                                 |
| table.columns                                                                                                               | array                                             | `("quantity","unit-price","tax-rate","total-price")`                                          | Column order (arrays replace)                                                   |
| table.align-header / align-body                                                                                             | dict by **key**                                   | pos center, description left, others right/center                                             | Keyed, not index-based (fixes S-24)                                             |
| table.figures                                                                                                               | str                                               | `"{font.figures}"`                                                                            |                                                                                 |
| **totals.** width / align / row-gap / col-gap / label / emphasis-size / weight / rule-thin / rule-thick                     | ..                                                | `66%` / right / `.6em` / `1em` / label / large / strong / thin / thick                        |                                                                                 |
| **notes.** fill / size                                                                                                      | ..                                                | muted / small                                                                                 | Style of CORE legal notes                                                       |
| **bank.** layout / qr-size / qr-min / fill / label-weight / value-weight                                                    | ..                                                | `"side"` / `5em` / `2cm` / `none` / regular / strong                                          | `"side"` \| `"below"` \| `"boxed"`; `qr-min` enforced by core                   |
| **payment.** emphasis / fill                                                                                                | ..                                                | strong / text                                                                                 | Replaces styling in locale strings (S-22)                                       |
| **signature.**gap                                                                                                           | length                                            | `1em`                                                                                         |                                                                                 |
| **footer.** pages / columns / size / fill / rule                                                                            | enum / auto\|array / ..                           | `"all"` / `auto` / caption / muted / `none`                                                   | `auto` = generated legal columns from sender/bank data (#18, R15)               |
| **page-number.** position / from / size                                                                                     | enum / int / len                                  | `"footer-right"` / `2` / caption                                                              | Localised by `env.lang` (R16)                                                   |
| **continuation.** enabled / size / rule                                                                                     | ..                                                | `true` / caption / hairline                                                                   | Header on pages >= 2 (R17)                                                      |
| **background.** first / rest                                                                                                | none\|content                                     | `none`                                                                                        | Letterhead SVG/PNG per page kind (R13)                                          |
| **stamp.** text / fill / size / angle                                                                                       | ..                                                | `none` / `tint(negative, 55%)` / `64pt` / `-30deg`                                            | DRAFT/PAID (R26)                                                                |
| **marks.** enabled / stroke / length / hole-length                                                                          | ..                                                | `true` / `stroke-of(hairline, mark)` / `2.5mm` / `4mm`                                        | Positions live in `geometry.marks`                                              |
| **a11y.** contrast / min-ratio                                                                                              | enum / float                                      | `"check"` / `4.5`                                                                             | `"check"` \| `"strict"` \| `"off"` (R5)                                         |
| **geometry.** profile                                                                                                       | str                                               | `"regional"`                                                                                  | Name, or `"regional"` = pick by `env.region` (R11)                              |
| geometry.paper                                                                                                              | str                                               | `"a4"`                                                                                        | Any Typst paper (R9)                                                            |
| geometry.margin                                                                                                             | sides                                             | 25/20/20/20 mm                                                                                | Content area on all pages                                                       |
| geometry.header.height                                                                                                      | length                                            | `27mm`                                                                                        | Page-1 letterhead zone                                                          |
| geometry.window                                                                                                             | none\|(x, y, width, height, return-height, inset) | DIN A: `20mm, 27mm, 85mm, 45mm, 17.7mm, 5mm`                                                  | `none` = address flows in the body                                              |
| geometry.info                                                                                                               | none\|(x, y, width)                               | `125mm, 32mm, 75mm`                                                                           | Information block rectangle                                                     |
| geometry.body                                                                                                               | (top: auto\|length, gap: length)                  | `auto`, `8.46mm`                                                                              | Where page-1 body starts (auto = below window/header)                           |
| geometry.marks                                                                                                              | (fold: array, hole: none\|length, x: length)      | `(87mm, 192mm)`, `148.5mm`, `5mm`                                                             | Fold/punch mark positions                                                       |
| geometry.references                                                                                                         | enum                                              | `"line"`                                                                                      | `"line"` (DIN Bezugszeichenzeile) \| `"info-block"`                             |
| geometry.reserve                                                                                                            | (last-bottom: length)                             | `0mm`                                                                                         | Brand-immune zone at the bottom of the last page (QR-bill, R18). Not prototyped |
| **assets.** logo / logo-alt                                                                                                 | none\|content / none\|str                         | `none`                                                                                        | Never resolved; content values                                                  |
| **parts.** letterhead, address, info, title, footer, continuation, line-items, bank-details, payment-goal, signature, frame | auto\|none\|function                              | `auto`                                                                                        | Never resolved; see section 5                                                   |

The prototype schema has 190 resolved leaves (`src/theme/schema.typ`).

### 3.2 DIN 5008 defaults: `themes.classic` on `geometry.din-5008-a`

`classic` pins the legacy literals so the default look stays recognisable. The research notes that "defaults are sacred" (docs-tests-intent §5.2).

```typst
#let classic-tokens = (
  color: (text-muted: luma(100), text-subtle: luma(80), surface-alt: rgb("e2e8f0"),
          label: rgb("475569"), positive: rgb("333333")),
  size: (label: 8pt, caption: 7pt, letter: 10pt),
)
#let din-5008-a = (geometry: (
  profile: "din-5008-a", paper: "a4",
  margin: (left: 25mm, right: 20mm, top: 20mm, bottom: 20mm),
  header: (height: 27mm),
  window: (x: 20mm, y: 27mm, width: 85mm, height: 45mm, return-height: 17.7mm, inset: 5mm),
  info: (x: 125mm, y: 32mm, width: 75mm),
  body: (top: auto, gap: 8.46mm),
  marks: (fold: (87mm, 192mm), hole: 148.5mm, x: 5mm),
  references: "line",
))
```

Rendered: `proto-tokens-first/demo/out-classic-1.png` / `-2.png` (continuation header and "Seite 2 von 2" on page 2).

### 3.3 A radically different layout in the same schema: `themes.modern` on `geometry.a4-digital`

There is no window, no marks, a full-bleed brand band, a "Bill to" address in the flow, an info block instead of a reference line, a coloured table header, a boxed bank block and centred page numbers from page 1.

```typst
#let modern-tokens = (
  letterhead: (arrangement: "band"),                       // fill defaults to color.primary
  table: (header-fill: "{color.primary}", header-text: "{color.on-primary}",
          header-rule-top: none, header-rule-bottom: none, row-fill-even: none,
          row-stroke: (bottom: 0.5pt + luma(220)), group-fill: "{color.surface-alt}"),
  totals: (width: 50%, rule-thick: "{stroke.regular}"),
  title: (show-date: false, size: 2em),
  address: (label: "Bill to"),
  bank: (layout: "boxed"),
  footer: (rule: "{stroke.hairline}"),
  page-number: (position: "footer-center", from: 1),
  marks: (enabled: false),
)
#let a4-digital = (geometry: (
  profile: "a4-digital", paper: "a4",
  margin: (left: 18mm, right: 18mm, top: 18mm, bottom: 22mm),
  header: (height: 38mm), window: none, info: none,
  body: (top: auto, gap: 8mm), marks: (fold: (), hole: none, x: 5mm),
  references: "info-block",
))
```

Rendered with `brand(color: rgb("#0f766e"), font: "Inter")`: `demo/out-modern-1.png`. The third demo is classic on `us-letter-10`, with the page number top right from page 1 (`demo/out-us-1.png`, 612 x 792 pt). The Swiss demo uses a right window picked by region `ch` and a brand from TOML (`verify/out-swiss-1.png`).

---

## 4. Cascade, precedence & merge semantics

### 4.1 Layers (lowest to highest)

| #   | Layer                        | Who writes it                                                                                                                                                                                                      | Mechanism                                                                                                                        |
| --- | ---------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | -------------------------------------------------------------------------------------------------------------------------------- |
| L0  | Base schema                  | package; injected by `invoice()` as `base:`                                                                                                                                                                        | `src/theme/schema.typ`                                                                                                           |
| L1  | Style preset                 | `build-theme(name:, ..patches)`                                                                                                                                                                                    | fold                                                                                                                             |
| L2  | Geometry profile             | `"regional"` resolves via `env.region` (`de/at`→din-5008-a, `ch`→sn-010130-right, `fr`→nf-z-11-001, `us`→us-letter-10, else din-5008-a) unless any patch names a profile; user geometry keys are re-applied on top | fold                                                                                                                             |
| L3  | User patches                 | `.with(p1, p2, ..)`, DSL blocks, data files, dotted keys; left to right, later wins                                                                                                                                | fold                                                                                                                             |
| —   | **Resolution**               | aliases, `$op` descriptors, `env`                                                                                                                                                                                  | once per `invoice()`                                                                                                             |
| L4  | Scoped patches               | `restyle(..)[..]`, nestable, sibling-isolated                                                                                                                                                                      | merge onto _source_, re-resolve                                                                                                  |
| L5  | Explicit component arguments | `bank-details(qr-code: (size: 3cm))`, `line-items(show-column: ..)`                                                                                                                                                | component wins (house `derive` precedent)                                                                                        |
| —   | Native Typst rules           | user `set`/`show` inside the body                                                                                                                                                                                  | innermost wins; the frame only sets `text(font,size,fill,lang)`, `par(justify)`, `hyphenate`, so a user can still override those |

**Which component arguments survive:** arguments that describe _data or per-instance behaviour_ stay on components (`show-column`, `show-total`, `show-information`, `qr-code.display`, `show-reference`). Visual arguments move to tokens (`qr-code.size` becomes `bank.qr-size`). A visual argument kept for convenience beats tokens. This settles S-21.

### 4.2 `auto` and `none`

- In patches, `auto` means **leave untouched**. It is dropped by `expand()`, exactly like `_clean-auto`. That is why every DSL parameter defaults to `auto`.
- As a token value, `none` means **off** (no fill, no rule, no page number, no window). `merge` stores `none` verbatim. It never uses `ensure`, which treats `none` as missing (loom gotcha 1.6).
- In `parts.*`, `auto` means the built-in renderer, `none` renders nothing (rejected for mandatory parts), and a function is an override.
- Data files cannot express `auto`, so absence means inherit. The string `"none"` becomes `none` in `from-data`.

### 4.3 Merge depth, by value kind (`engine.typ: merge`)

| Value kind                                   | Behaviour                                                        | Example                                                                                           |
| -------------------------------------------- | ---------------------------------------------------------------- | ------------------------------------------------------------------------------------------------- |
| group (dict in the schema)                   | deep merge, **strict**: unknown key → panic listing allowed keys | `(table: (header-fill: red))`                                                                     |
| _sides_ leaf (listed in `sides-paths`)       | **fold**: `x/y/rest/left/..` normalised, only given sides change | `header-inset: (y: .8em)` keeps x = .4em (verified in the Swiss demo)                             |
| group that is `none` in the current tree     | merged onto its **template**                                     | `geometry(window: (x: 118mm))` on `a4-digital` gets the other window keys from the DIN A template |
| array, scalar, content, function, descriptor | replace                                                          | `table.columns`, `row-fill-even: (x, y) => ..`                                                    |
| `replace(v)`                                 | replace wholesale, even for groups                               | `geometry: replace(my-complete-profile)`                                                          |
| dotted key                                   | expanded to nesting before merge                                 | `"table.header-fill": red`                                                                        |
| open groups (`open-paths`)                   | any key allowed                                                  | `table.align-header: (sku: left)`                                                                 |

### 4.4 Aliasing & derivation

A leaf is one of the following:

- a literal;
- an alias string `"{path}"` (whole-token reference, TOML-friendly);
- a descriptor `("$op": ..)` built by `tint/shade/mix/on/legible/scale/times/stroke-of/pick`;
- `derive(get => ..)`, which is the escape hatch.

Resolution is **lazy and recursive against the merged tree**: `resolve-value(tree, v)` dereferences on demand, with a depth guard of 32 for cycles. Order does not matter, and no tier ordering is needed. Descriptors make the common derivations data, so a theme package or a JSON file can contain them. Only `derive` needs Typst code.

One seed restyles everything. `brand(color: rgb("#ec4899"))` yields `on-primary` = black (5.9:1 beats white's 3.53:1) and a derived `surface-alt`. `legible("{ref.color.brand}", white)` repairs the brand to 5.48:1 (`verify/out-specimen-1.png`). The research's contrast math (prior-art C7) is reused verbatim in `color.typ`.

### 4.5 When resolution happens and what it costs

- **Once** in `invoice()`, before `weave`: fold patches, pick geometry, resolve, validate. This is pure data work. comemo memoises it, so it is free on incremental recompiles.
- The result travels in **one ctx key** `theme = (kind, name, env, lints, sealed: metadata((source, tokens)))`.
- **Measured finding:** storing the ~190-leaf `tokens` and the unresolved `source` as plain dicts in ctx cost **+280 ms** on a 62-item invoice (1019 ms vs 698 ms baseline). Every loom closure call hashes its arguments at about 20 ns per entry, as research measured. Wrapping both trees in an opaque `metadata(..)` content value, which Typst hashes lazily, brought it to **+15 ms (705 ms vs 690 ms)**.
- `restyle` merges and re-resolves once per scope and pass. **60 scoped overrides** in the same invoice cost **+30 ms** (714 to 733 ms).
- Per-row scoped tokens inside the table are re-resolved per styled entry. Identical inputs are memoised.

---

## 5. Renderer / part contract

### 5.1 Themable parts

| Part           | Called by                              | View (built by core)                                                                                     | Stability in 0.5.0            |
| -------------- | -------------------------------------- | -------------------------------------------------------------------------------------------------------- | ----------------------------- |
| `frame`        | root.draw (inside core)                | `body` instead of a view; `(ctx, body, super:)`                                                          | experimental (level-5 escape) |
| `letterhead`   | frame (page 1, zone `geometry.header`) | `(subject, page-width, margin, height)` + `ctx.sender`                                                   | stable                        |
| `address`      | frame (window) or flow                 | `(placement: "window"\|"flow", window)` + `ctx.recipient`                                                | stable                        |
| `info`         | frame                                  | `(style: "line"\|"info-block", pairs: ((label, value), ..))`                                             | stable                        |
| `title`        | frame                                  | `(subject, place, date)`                                                                                 | stable                        |
| `footer`       | frame, every page per `footer.pages`   | `(columns: array<content>)`                                                                              | stable                        |
| `continuation` | frame, pages >= 2                      | `(subject, sender-name)`                                                                                 | stable                        |
| `line-items`   | line-items.draw                        | line-items view (5.3)                                                                                    | view fields: provisional      |
| `bank-details` | bank-details.draw                      | `(sender: (name, bank, iban, bic), reference, text, show-reference, payment-amount, qr-code: (display))` | stable                        |
| `payment-goal` | payment-goal.draw                      | `(days, date, total)`                                                                                    | stable                        |
| `signature`    | signature.draw                         | `(name, signature)`                                                                                      | stable                        |

**Uniform signature:** every part is `(ctx, view, super: none) => content`. It is ctx-first like every existing slot (api-philosophy P12). `super` is the built-in, which the caller binds. There is one convention instead of today's five callback shapes (S-5). Users who do not need `super` write `(ctx, view, ..) => ..`. Tokens are read via `themes.tokens-of(ctx)`, which is the only supported accessor; the `sealed` layout is internal.

**Wrap versus replace** (verified, `verify/wrap.typ`):

```typst
part("signature", (ctx, view, super: none) => {
  super(ctx, view)                                   // wrap: keep built-in
  text(size: 8pt, fill: gray)[Digitally issued – valid without signature.]
})
part("letterhead", (ctx, view, super: none) => my-own-header(ctx))   // replace
```

`dispatch(ctx, name, view, builtin)` treats `auto` as the built-in, `none` as nothing, and a function as `f(ctx, view, super: builtin)`.

### 5.2 Addressing the research findings on views

1. **Pre-formatted versus raw.** Every money, percent, date or quantity value in a v2 view becomes a record `(value: decimal|datetime|ratio, text: str)`, for example `item.total.value` / `item.total.text`. Themes can colour negatives and re-format amounts, and the formatted text stays locale-correct. Prototype status: frame views follow this. The line-items adapter still consumes the old view (listed as known weakness).
2. **Inconsistent names and types.** Items get `surcharges` (plural), `has-surcharges`, `formatted-total`, `taxes[].rate` as a record like above, and `description: none` instead of `[]`.
3. **Stale ctx.** Frame parts are called from root.draw with the _fresh_ ctx (normalised references, `bank`, `items`). Body parts receive everything they need in `view`. `ctx.global` is declared internal and not part of the contract. Anything document-wide a body part may need goes into `view.document` = `(total, currency, tax-mode, has-prepayments, kind)` (to be published by root).
4. **Presentation decisions stay in data.** Column auto-visibility stays a component concern (`show-column`). Themes get `view.layout.show-*`, plus `view.layout.forced-*` to tell forced settings from auto (component-contract finding 5).

### 5.3 Line-items view v2 (provisional in 0.5.0)

```
view = (
  entries: array<item | group-header | group-footer>,   // render order, each has `kind`, `pos`, `level`, `style` (scoped patches)
  items: array<item>,
  discounts, surcharges: array<modifier>,
  prepayments: array<prepayment>,
  taxes: array<(rate: (value, text), category: str, amount: (value, text), grounds, marker)>,
  total: (net, gross, due, prepaid: (value, text)),
  layout: (show-pos, .., forced: dict),                 // renamed from layout-information
  notes: array<(kind, text, marker)>,                    // computed by CORE; rendered by core-notes
  tax-mode, tax-exempt-small-biz,
)
```

### 5.4 Stability tiers

- **Stable (frozen in 0.5.0):** the calling convention; the DSL helper names; token paths of `ref.*`, the semantic tiers (`color/font/size/weight/space/stroke`) and `geometry.*`; enum values listed in section 3; part names, the part signature and the stable view fields.
- **Provisional:** component-tier token paths. They may be added, and a rename ships an alias for one minor version (the schema supports alias leaves natively: the old path simply becomes `"{new.path}"`). Also provisional: the line-items view.
- **Experimental:** `parts.frame`, `from-dtcg`, `geometry.reserve`, row-level scoped tokens beyond fill and text.

### 5.5 Where compliance-critical output lives (no theme can lose it)

| Output                                                                        | Where                                                                                                     | Theme influence                                                                                    |
| ----------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------- |
| PDF metadata (title, author, date, keywords incl. ZUGFeRD/Factur-X)           | root.draw, before the frame (`src/components/root.typ`)                                                   | none (verified: `themes.blank` now passes `ua-1`; `dc:title` present; `CreateDate` = invoice date) |
| `text.lang` / `region`                                                        | root.draw; S-17 fixed in `invoice.typ` (`lang = strings.meta.lang`)                                       | none (verified `dc:language` en-DE for `locale.en-de`, "Page 1 of 2")                              |
| ZUGFeRD XML attachment                                                        | root.draw (unchanged)                                                                                     | none (verified `factur-x.xml` under `--pdf-standard a-3b` with modern + SVG logo)                  |
| Legal notes (small-business clause, exemption grounds, uniform tax statement) | `core-notes` is appended by the line-items **component** after the `line-items` part                      | style only (`notes.fill/size`); a replaced `line-items` part cannot drop them                      |
| Zero-tax suppression, totals rows                                             | core decides and puts them in `view` (v2); prototype keeps it in the totals renderer                      | style only                                                                                         |
| EPC-QR payload, EUR rule, min size, black on white quiet box                  | `core-epc-qr` (core helper)                                                                               | part chooses position only; `bank.qr-size` is clamped to `bank.qr-min`                             |
| Mandatory parts                                                               | `line-items`, `bank-details`, `payment-goal`, `address` may not be `none`                                 | validation panic                                                                                   |
| Logo alt text                                                                 | validation: `assets.logo` requires `assets.logo-alt`                                                      | —                                                                                                  |
| Swiss QR-bill slip (future)                                                   | core component rendered in a reset scope with `font.regulated`, black, fixed sizes, in `geometry.reserve` | none                                                                                               |

---

## 6. Page frame & arbitrary formats

**invoice-pro owns `set page`, and letter-pro is dropped.** The prototype frame is about 170 lines (`src/theme/frame.typ`). It is driven only by `geometry.*` plus component tokens:

- `set page(paper: g.paper, margin: g.margin, background:, foreground:, header:, footer:)` sits at the frame's top level, never inside an `if` (the S-1 bug).
- **Background** (`context`): `background.first` / `background.rest` (SVG/PNG/native; suppressed in pre-printed mode), then fold and hole marks from `geometry.marks`, painted with `marks.stroke`. Both compose in one callback, because `set page(background:)` values do not compose (C10).
- **Header** (`context`): the continuation part on pages >= 2, plus the page number if `page-number.position == "header-right"`.
- **Footer** (`context`): the footer part per `footer.pages` (`"all"`, `"first"`, `"rest"`, `none`) and a localised page number from `page-number.from`. Parts get `ctx` **as an argument**, and data is computed outside `context`, so no loom motif ever hides inside `context` (S2).
- **Page-1 zones**: `place(top+left, dx: zone.x - margin.left, dy: zone.y - margin.top, ..)` for letterhead (full width), window address and info block. Source order equals reading order: letterhead, address, info, title, body (a11y §6.2).
- **Body start**: `geometry.body.top`, or with `auto`, `window.y + window.height + gap` (or `header.height + gap` without a window).
- **Flow layouts** (`window: none`): the address and info block form a two-column grid in the flow.
- **Pre-printed** (`letterhead.mode: "pre-printed"`): no letterhead, footer, continuation header or background. Geometry, window and marks are kept (verified `verify/out-preprinted-1.png`).
- **Localised page numbers**: the prototype uses a de/en/fr/it/es table keyed by `ctx.locale.lang`. The proposal moves it into the locale schema as `strings.document.page-number: (n, total) => content`.
- **Multi-column legal footer (#18)**: `footer.columns: auto` generates company, contact, tax IDs and bank columns from `sender` and `bank` with locale labels. An array of content replaces it. Proposed follow-up: `sender.register`, `sender.management` and `sender.capital`, so that § 35a GmbHG / RCS / REA columns generate automatically (coordination with the invoice-header API).
- **Reserved zones**: `geometry.reserve.last-bottom: 105mm`. The frame ends the body with `v(1fr)` and a non-breaking block of that height, rendered with footer and page number suppressed on that page, in a reset scope. Not prototyped.

### 6.1 A completely new format without forking: data first

A Japanese Nippon-LL envelope on A4 with the window top left, 2-fold:

```typst
#let nippon-ll = (geometry: (
  profile: "nippon-ll", paper: "a4",
  margin: (left: 20mm, right: 20mm, top: 18mm, bottom: 20mm),
  header: (height: 30mm),
  window: (x: 25mm, y: 25mm, width: 90mm, height: 45mm, return-height: 10mm, inset: 4mm),
  info: (x: 120mm, y: 30mm, width: 70mm),
  body: (top: auto, gap: 8mm),
  marks: (fold: (148.5mm,), hole: none, x: 5mm),
  references: "info-block",
))
#show: invoice.with(theme: themes.classic.with(nippon-ll), ..)
```

**Where data stops.** A _new arrangement_ is structure, not a value. Examples are a left sidebar with logo and contact, or the address below the table. The `letterhead.arrangement` and `bank.layout` enums cover the common products (Lexware's positions, Odoo's layouts), but not everything. Beyond them you override a part (`letterhead`, `address`) or, as the very last resort, the whole `frame`. Tokens stay available inside, and core compliance stays outside.

### 6.2 A third-party theme package on Typst Universe

Because descriptors are plain dictionaries, a theme package needs **no import of invoice-pro at all**. That removes the version-bound loom key problem entirely: no motifs, no `info.*`, nothing keyed to `<invoice-pro:X.Y.Z>`.

```typst
// @preview/invoice-theme-nordic:0.1.0  lib.typ  (zero dependencies)
#let tokens = (
  ref: (color: (brand: rgb("#1e3a5f"), accent: rgb("#c9a227")), type: (base: 9.5pt, ratio: 1.25)),
  font: (body: ("Source Sans 3", "Liberation Sans"), heading: ("Fraunces", "Libertinus Serif")),
  table: (header-fill: none, header-rule-top: ("$op": "stroke", thickness: 2pt, paint: "{color.accent}"),
          row-fill-even: none, row-stroke: (bottom: 0.4pt + luma(210))),
  totals: (label: "{color.accent-text}"),
  letterhead: (arrangement: "logo-left"),
)
#let parts = (
  signature: (ctx, view, super: none) => { super(ctx, view); line(length: 4cm, stroke: 0.4pt) },
)
#let theme = (tokens, (parts: parts))           // an array of patches
```

```typst
// consumer
#import "@preview/invoice-theme-nordic:0.1.0" as nordic
#show: invoice.with(theme: themes.build-theme(name: "nordic", ..nordic.theme), ..)
// or on top of a preset:  themes.minimal.with(nordic.theme)
```

Forward compatibility works like locale: the running invoice-pro injects its base schema. Tokens added later get defaults. A token the package references that the running version renamed resolves via the rename alias for one minor version.

---

## 7. Walkthroughs

### P1 – Freelancer, digital only, five minutes

```typst
#show: invoice.with(
  theme: themes.classic.with(themes.custom.brand(
    color: rgb("#0f766e"), font: ("Inter", "Liberation Sans"),
    logo: image("logo.svg"), logo-alt: "Studio Lina Berg",
  ), themes.custom.marks(enabled: false), themes.custom.letterhead(arrangement: "logo-left")),
  tax-exempt-small-biz: true, sender: (..), recipient: (..), invoice-nr: "2026-014",
)
```

### P2 – GmbH: pre-printed paper, digital letterhead, ZUGFeRD

```typst
#let mode = sys.inputs.at("output", default: "pdf")        // print | pdf | einvoice
#let acme = themes.custom.brand(color: rgb("#003a70"), accent: rgb("#e2001a"),
  font: ("Source Sans 3", "Liberation Sans"), logo: image("acme.svg"), logo-alt: "ACME Maschinenbau GmbH")
#show: invoice.with(
  theme: themes.classic.with(acme, {
    import themes.custom: *
    geometry(profile: "din-5008-b", margin: (bottom: 32mm))
    letterhead(mode: if mode == "print" { "pre-printed" } else { "generated" })
    if mode == "pdf" { background(first: image("lh-p1.svg"), rest: image("lh-p2.svg")) }  // SVG: PDF/A-safe
    marks(enabled: mode == "print")
    page-number(position: "footer-right", from: 1)
  }),
  zugferd: if mode == "einvoice" { "en16931" },
  sender: (name: "ACME Maschinenbau GmbH", vat-id: "DE123456789", extra: (..)),
  ..
)
```

`footer.columns: auto` produces the company, contact, VAT and bank columns on every page. A `derive` could drop `background.*` when `env.zugferd != none`, the pattern verified in `verify/specimen.typ`.

### P3 – Swiss SME, right window, QR-bill

```typst
#show: invoice.with(
  locale: locale.de-ch,                               // geometry "regional" -> sn-010130-right
  theme: themes.classic.with(themes.custom.brand(color: rgb("#7a1f2b"),
    font: ("Source Serif 4", "Libertinus Serif"), logo: image("logo.svg"), logo-alt: "Treuhand Aare AG"),
    themes.custom.geometry(reserve: (last-bottom: 105mm))),   // planned: QR-bill zone
  ..
)
#line-items[..]
// #qr-bill(..)   future core component: font.regulated, black, fixed sizes, scissors line
```

Verified part: right window, left info block, CHF formatting, no EPC-QR for CHF (core rule): `verify/out-swiss-1.png`.

### P4 – Agency with twelve white-label brands in TOML

```typst
#let job = json(sys.inputs.job)
#let entity = toml("brands/" + job.brand + ".toml")
#show: invoice.with(
  theme: themes.modern.with(themes.from-data(entity.theme, assets: (
    logo: image("brands/" + job.brand + ".svg"), logo-alt: entity.sender.name))),
  sender: entity.sender, ..job.header,
)
```

```toml
[theme.ref.color]
brand = "#0b3d91"
accent = "#ffb000"
[theme.font]
body = ["IBM Plex Sans", "Liberation Sans"]
[theme.table]
header-inset = { y = "0.8em" }      # folds, x kept
```

A typo such as `header-fil` fails with the path and the list of allowed keys (section 8).

### P5 – SaaS batch in CI with DTCG tokens

```typst
// theme.typ – built once, imported by every job
#let company = themes.modern.with(
  themes.from-dtcg(json("design/brand.tokens.json"), map: (
    "color.brand.primary": "ref.color.brand", "color.brand.secondary": "ref.color.accent",
    "typography.body.fontFamily": "font.body")),
  themes.custom.accessibility(contrast: "strict"),     // fail the build, not the customer
  themes.custom.marks(enabled: false))
```

Run with `typst compile --font-path fonts --pdf-standard a-3a,ua-1 --input data=job.json`. `themes.specimen(company)` is rendered in CI as a QA artefact, because silent font fallback cannot be detected inside Typst (C13).

### P6 – Design studio: Stripe-like on DIN B, one part replaced

```typst
#show: invoice.with(
  theme: themes.minimal.with({
    import themes.custom: *
    brand(color: rgb("#111827"), accent: rgb("#6366f1"), font: "Inter", heading-font: "Fraunces",
          logo: image("mark.svg"), logo-alt: "Atelier Nord")
    geometry(profile: "din-5008-b")
    totals(emphasis-size: 1.6em, width: 40%)
    tokens("table.header-rule-bottom": themes.stroke-of(0.4pt, "{color.accent}"))
    part("payment-goal", (ctx, view, super: none) => {
      let t = themes.tokens-of(ctx)                    // resolved tokens of this scope
      block(fill: t.color.surface-alt, inset: 1em, radius: 6pt, super(ctx, view))
    })
  }),
  ..
)
```

### P7 – Public-sector / B2C supplier (EAA)

```typst
#show: invoice.with(
  theme: themes.classic.with(themes.custom.brand(color: rgb("#00843d"),
      logo: image("stadtwerke.svg"), logo-alt: "Stadtwerke Musterstadt"),
    themes.custom.accessibility(contrast: "strict"), themes.custom.marks(enabled: false)),
  ..
)
// typst compile --pdf-standard a-3a,ua-1   (verified: classic passes a-3a,ua-1; blank passes ua-1)
```

### P8 – US subsidiary on Letter, same corporate brand

```typst
#import "corporate.typ": corporate            // an array of patches (brand + fonts), shared with DE
#show: invoice.with(
  locale: locale.en-us,                       // region us -> regional picks us-letter-10
  theme: themes.classic.with(corporate, themes.custom.footer(columns: (
    [*Remit to:* ACME Inc., PO Box 42, Austin TX], [billing\@acme.com])), themes.custom.page-number(position: "header-right", from: 1)),
  ..
)
```

Verified with an explicit `themes.geometry.us-letter-10` (`demo/out-us-1.png`). `locale.en-us` does not exist yet.

### (9) Third-party theme author

See section 6.2. The author ships a dictionary (plus optional part functions) and tests it with `themes.resolve-theme(themes.build-theme(..nordic.theme))` in their own CI, against the currently published invoice-pro.

### (10) Scoped style for one subtree

```typst
#line-items[
  #item([Brand workshop], price: 2400)
  #restyle(themes.custom.palette(primary: rgb("#b45309")))[
    #group([Optional extras], description: [Only billed if accepted])[
      #item([Print collateral], price: 650)
      #item([Photo shoot], price: 1200)
    ]
  ]
]
#restyle(themes.custom.bank(layout: "boxed"), themes.custom.palette(primary: rgb("#6d28d9")))[
  #bank-details(..)                           // a whole component in a different style
]
#themed(t => block(fill: t.color.surface-alt, inset: 8pt)[Thank you!])   // user content reads tokens
```

Only the patch is scoped: `primary` changes, and `surface-alt` and therefore `group-fill` _re-derive_ inside the scope. The orange group in `demo/out-modern-1.png` was never given an explicit colour. Sibling groups keep the teal-derived fill.

---

## 8. Validation & error messages

| When                | What                                            | Example message (real prototype output)                                                                                                                                      |
| ------------------- | ----------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `.with(..)` / DSL   | DSL helper with an unknown profile              | `assertion failed: theme::custom::geometry: unknown profile \`din-5008-c\`. Known: regional, din-5008-a, din-5008-b, sn-010130-right, nf-z-11-001, us-letter-10, a4-digital` |
| `invoice()` → build | patch not a dict                                | `theme: a patch must be a dictionary or an array of dictionaries, found string ("modern")`                                                                                   |
| merge               | unknown token (strict, full path, allowed keys) | `theme: unknown token \`table.header-fil\`. Allowed keys in \`table\`: header-fill, header-text, header-weight, ...`                                                         |
| merge               | patching `env`                                  | ``theme: `env` is injected by invoice() and cannot be patched``                                                                                                              |
| resolve             | dangling alias                                  | ``theme: alias `{color.brand}` points to a token that does not exist``                                                                                                       |
| resolve             | cycle                                           | `theme: token alias/derivation cycle detected (depth > 32)` (the production version adds the chain of paths)                                                                 |
| validate            | leaf type / enum                                | `theme: token \`letterhead.arrangement\` ("banner") must be of "subject-left" \| "logo-left" \| "band" \| "centered"`                                                        |
| validate            | leaf type                                       | `theme: token \`table.row-fill-even\` (12pt) must be of color \| none \| function \| array`                                                                                  |
| validate            | mandatory part                                  | ``theme: part `bank-details` carries legally required output and cannot be `none`. Hide it with tokens or wrap the built-in via `super` instead.``                           |
| validate            | logo without alt                                | ``theme: `assets.logo` needs `assets.logo-alt` (alt text is mandatory under PDF/UA-1)``                                                                                      |
| validate            | contrast, `a11y.contrast: "strict"`             | `theme: contrast below 4.5:1 (a11y.contrast: "strict"): table.header-text on table.header-fill: 3.53:1`                                                                      |
| invoice             | preset called                                   | `theme: pass the preset UNCALLED, e.g. \`theme: themes.classic\` or \`themes.classic.with(..patches)\`; invoice() evaluates it.`                                             |

- **Unknown keys** always panic. Strictness is the house philosophy (P5), and the locale version was broken (I-2). Open maps are explicitly listed.
- **Low contrast**: with `"check"` (the default), lints are collected into `theme.lints` and shown by `themes.specimen`. Typst has no warning API, so the default cannot be louder than that. `"strict"` panics. `"off"` skips the check. Checked pairs: header text/fill, text/zebra, description/zebra, totals label/paper, on-primary/primary. Built-in presets must have zero lints (a CI test).
- **Planned PDF/A guards** when `env.zugferd != none` (not prototyped):
  - a `cmyk` colour in any resolved token panics with ``theme: token `color.primary` is a CMYK colour; PDF/A-3 (ZUGFeRD) rejects CMYK. Use rgb() or oklch().``
  - `assets.logo` or `background.*` holding an `image` whose `source` ends in `.pdf` panics with `theme: background.first embeds a PDF image, which --pdf-standard a-3b rejects; convert it to SVG.`
- Fonts cannot be validated (C13). This is documented, and `specimen` renders each font role.
- The type checks use the house `types.require` phrasing. The production version should route leaf checks through `display-matcher` for the pattern text.

---

## 9. Internals sketch

### 9.1 Module layout (`src/theme/`, all in the prototype)

| File           | Lines | Role                                                                                                         |
| -------------- | ----- | ------------------------------------------------------------------------------------------------------------ |
| `engine.typ`   | 230   | descriptors, `expand` (dotted keys, drop auto), `normalize-sides`, strict `merge`, `resolve-value`/`resolve` |
| `color.typ`    | 50    | luminance, contrast, on-color, ensure-contrast, tint/shade                                                   |
| `schema.typ`   | 250   | `base-tokens`, `sides-paths`, `templates`, `open-paths`, `leaf-types`, `mandatory-parts`                     |
| `geometry.typ` | 150   | profiles + `region-defaults`                                                                                 |
| `build.typ`    | 125   | `normalize-patches`, `validate`, `build`, `build-theme`                                                      |
| `presets.typ`  | 55    | classic / modern / minimal / blank as data                                                                   |
| `custom.typ`   | 70    | DSL                                                                                                          |
| `data.typ`     | 40    | `from-data`                                                                                                  |
| `parts.typ`    | 400   | `dispatch`, built-in parts, token adapter for the table/totals renderer, `core-notes`, `core-epc-qr`         |
| `frame.typ`    | 175   | page frame                                                                                                   |
| `scope.typ`    | 35    | `restyle`, `themed`                                                                                          |
| `specimen.typ` | 25    | QA page                                                                                                      |

The old `src/themes/` (base-theme, DIN-5008, blank) is deleted. `src/themes/components/line-items/*` becomes `src/parts/line-items/*` and loses its 50 parameters in milestone M6 (section 12). Until then the adapter maps tokens to the existing parameters, adding one param (`color-group`) and per-entry `style-tokens`.

### 9.2 Plumbing

1. `invoice.typ`: `eval-locale.lang = strings.meta.lang` (S-17 fix). `env = (region, lang, zugferd, kind)`. `theme-fn = theme` if it is a function, otherwise `themes.classic.with(theme)`. `eval-theme = theme-fn(base: base-tokens, env: env)`, then the `kind` assertion, then `inputs.theme = eval-theme`.
2. `root.draw`: normalise references (unchanged), attach ZUGFeRD (unchanged), `set document(..)` (moved from the DIN theme), then `frame(ctx, body)` or the `parts.frame` override.
3. Components: the draw becomes `parts.dispatch(ctx, "<name>", view, parts.<builtin>)`. `line-items` additionally appends `parts.core-notes(ctx, view)`. Its scope puts `theme.scope-patch = ()` so that only restyles _inside_ it are recorded.
4. `group.measure` and `item.measure` add `style: ctx.theme.scope-patch` to their signal. `tree.typ` and the line-items view copy it onto entries. The adapter resolves `source + style` per styled entry into `style-tokens` (row fill, group fill, group text), which `table.typ` reads.
5. **One ctx key** (`theme`). Built-in renderers never read tokens from anywhere else. Defaults are defined once in `schema.typ`. The heavy trees ride in `sealed: metadata(..)` (section 4.5).

### 9.3 Performance summary (typst 0.15.1, 62-item invoice, median of 3)

| Variant                                   | Time    |
| ----------------------------------------- | ------- |
| 0.4.2 baseline (DIN-5008 via letter-pro)  | 690 ms  |
| tokens-first, trees as plain dicts in ctx | 1019 ms |
| tokens-first, sealed in `metadata`        | 705 ms  |
| same + 60 `restyle` scopes                | 733 ms  |

---

## 10. Feasibility evidence

Everything lives in `scratchpad/proto-tokens-first/`, a private copy of `proto/src`, and was compiled with typst 0.15.1. The repository was not touched.

| File                                                                                                                             | Verifies                                                                                                                                                                               | Result                                         |
| -------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------- |
| `src/theme/engine.typ`, `schema.typ`, `build.typ`                                                                                | strict merge, dotted keys, auto = untouched, sides folding, templates for `none` groups, aliases, `$op` descriptors, `derive`, geometry "regional", validation                         | works                                          |
| `demo/body.typ`                                                                                                                  | ONE invoice body (items, discount, two groups, payment goal, bank, signature)                                                                                                          | shared by all demos                            |
| `demo/classic.typ` → `demo/out-classic-{1,2}.png`                                                                                | format 1: classic on DIN A (regional, de); page 2 continuation header, footer on all pages, "Seite 2 von 2"                                                                            | works                                          |
| `demo/modern.typ` → `demo/out-modern-{1,2}.png`                                                                                  | format 2: modern band on a4-digital, one seed colour, Inter; **scoped override**: orange group via `restyle(palette(primary: ..))` with re-derived fill; boxed bank; QR black on white | works                                          |
| `demo/us.typ` → `demo/out-us-{1,2}.png`                                                                                          | format 3: classic on US Letter #10 (612x792 pt), dotted-key patch, alias value, "Page 1 of 2" top right in English (lang fix)                                                          | works                                          |
| `verify/swiss.typ` → `out-swiss-1.png`                                                                                           | `locale.de-ch` → sn-010130-right; brand from **TOML** (`verify/brand.toml`); logo content + alt; `header-inset: {y}` fold; stamp "ENTWURF"; CHF → no EPC-QR                            | works                                          |
| `verify/preprinted.typ` → `out-preprinted-1.png`                                                                                 | pre-printed: letterhead, footer and background suppressed; window and marks kept                                                                                                       | works                                          |
| `verify/wrap.typ` → `out-wrap-1.png`                                                                                             | two `table(..)` calls in one DSL block both apply (I-1 fixed); `part("signature")` wraps `super`; custom footer columns; `restyle` around a whole `bank-details`                       | works                                          |
| `verify/themed.typ` → `out-themed-1.png`                                                                                         | `themed(t => ..)` inside and outside `restyle`                                                                                                                                         | works; showed a band-on-DIN overflow (see §11) |
| `verify/specimen.typ` → `out-specimen-1.png`                                                                                     | pink seed → auto on-colour; `legible` repair; region fr → nf-z-11-001; `derive` on `env.zugferd`                                                                                       | works                                          |
| `verify/errors.typ --input case=1..12`                                                                                           | 12 validation paths, messages in §8                                                                                                                                                    | all panic as designed                          |
| `verify/zugferd.typ --pdf-standard a-3b` → `zugferd-a3b.pdf`                                                                     | modern + SVG logo + band under PDF/A-3b; `factur-x.xml` attached; XMP title/keywords/`en-DE`/CreateDate from core                                                                      | works                                          |
| `verify/zugferd.typ --pdf-standard ua-1`, `demo/classic.typ --pdf-standard a-3a,ua-1`, `verify/blank-ua.typ --pdf-standard ua-1` | PDF/UA; **blank now passes ua-1** (metadata in core)                                                                                                                                   | works                                          |
| `verify/bench*.typ`, `bench-baseline/`                                                                                           | cost model (§4.5 / §9.3), sealed-metadata finding                                                                                                                                      | measured                                       |

**What failed or is incomplete:**

1. The first bench put trees in ctx as plain dicts: +280 ms. Fixed by sealing.
2. `show` is a Typst keyword, so `show:` keys in dict literals do not parse. Tokens use `pages` / `enabled` instead, and this is a naming rule for the schema.
3. The line-items renderer is still the old 50-parameter component behind a token adapter. View v2 is designed, not built.
4. `geometry.reserve` (QR-bill), `from-dtcg` and the PDF/A asset guards are not prototyped. `resolve-theme` is prototyped and tested (`verify/resolve.typ` asserts derived on-colour, sides fold and US region geometry).
5. Not run on typst 0.14.0. The code avoids 0.15-only APIs (`dictionary.map/filter`, `path()`), but `to-absolute()`, the lazy hashing of `metadata` and the PDF/A behaviour were only observed on 0.15.1.
6. The table header-fill gap at the spacer columns (E17) still exists (visible in the modern header).
7. Pixel identity with 0.4.2 was not attempted. The own frame is close to, but not identical with, letter-pro's DIN output, so references need a one-time review.

---

## 11. Trade-offs, risks & rejected alternatives

**Honest weaknesses**

- **Data stops at structure.** Arrangement enums (`letterhead.arrangement`, `bank.layout`, `geometry.references`) cover common products, but a genuinely new composition needs a part override. Tokens also cannot measure content. `modern` on DIN geometry puts a tall sender block into a 27 mm band and overflows (`verify/out-themed-1.png`). A validator cannot see that. Mitigation: presets declare the geometry they were designed for, and `specimen` shows a sample.
- **Learning surface.** About 190 tokens is a lot. The three tiers keep the _frozen_ surface small (ref + semantic, about 60), but docs must be generated from `schema.typ` (a table per group). Otherwise docs drift (I-6/I-8).
- **Stringly-typed aliases.** `"{color.primray}"` is caught at resolve time with a clear message, but there is no IDE help. The `..named` DSL helpers give up per-parameter autocomplete and doc comments in exchange for zero schema drift. `brand`, `geometry`, `background`, `stamp`, `accessibility` and `part` keep real named parameters.
- **Row-level scoping is partial.** Inside `line-items`, a `restyle` affects only tokens the table reads _per row_ (row fills, group fill and text). Cell insets, column set and header stay table-wide, because a table is drawn once by its parent (loom §3.4).
- **Sealing relies on an engine property.** Lazy content hashing is observed behaviour, not a documented guarantee. If it ever changes, it costs about 300 ms. A loom-side fix (below) would make it robust.
- **The own frame is new code.** It removes letter-pro's hard limits but takes over DIN precision. Every profile needs a visual reference test. Swiss and French millimetre values need verification against Swiss Post masks / AFNOR (business-req open question 2).
- **Contrast "check" is silent.** There is no warning API, so only `strict` or `specimen` surface problems.

**Deliberately left out:** CMYK/spot colours and bleed (R34), font loading (R35), carry-over subtotals (R21, needs table-internal state), theme-supplied component default args (MUI `defaultProps`, D13). Component props stay on components.

**Mark experimental in 0.5.0:** `parts.frame`, `from-dtcg`, `geometry.reserve`, row-level scoped tokens beyond fills, the line-items view v2 field set.

**Rejected alternatives**

- _cetz-style implicit same-name inheritance_ (D11): explicit aliases give the same reach without magic. Only `auto`/`none` semantics and sides folding are kept.
- _elembic custom elements_ (D15): context opacity against loom, rule-depth limits, a dependency.
- _valkyrie_ (D16): the in-house strict merge plus `types.require` phrasing suffices.
- _`eval` for data files_: not file-sandboxed on 0.15.1 (C8). `from-data` uses a regex parser.
- _Flat prefixed parameters_ (`color-row-odd`, the fletcher style): the status quo already breaks at 50 params and 5 places of defaults.
- _Tier-ordered eager resolution_: this requires authors to know tier order. Lazy recursive resolution with a cycle guard is order-free and measured cheap.
- _Theme = zero-arg function returning slots_: no base injection and no validation, and it caused footgun I-5.
- _Keeping letter-pro_: it blocks R9, R13, R15, R16, R17 and R18.

---

## 12. Implementation roadmap (solo maintainer, each step shippable)

| Milestone                               | Scope                                                                                                                                                                                                                                                                                                                            | Ships as               | Tests                                                                                                                                                              |
| --------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| **M0 – Core hygiene** (1 evening)       | `lang` fix (S-17); `set document` into root; `blank` passes ua-1                                                                                                                                                                                                                                                                 | 0.4.3 bugfix           | `tests/integration/lang-page-number/` (en → "Page"), ua-1 compile test                                                                                             |
| **M1 – Token engine**                   | `src/theme/{engine,color,schema,build}.typ`; `invoice(theme:)` accepts function/dict/array; seal in metadata; body parts (`bank-details`, `payment-goal`, `signature`, line-items adapter, `core-notes`, `core-epc-qr`) read tokens; the DIN document still renders via letter-pro, reading `letterhead.*` tokens where possible | 0.5.0-dev              | unit tests on `resolve-theme` (token assertions: seed → derived values; fold; strictness); existing DIN refs unchanged except the body                             |
| **M2 – Own frame + DIN geometry**       | `frame.typ`, `geometry.din-5008-a/b`, marks, footer every page, continuation, localised page numbers (`strings.document.page-number` in the locale schema), `footer.columns: auto`; drop letter-pro                                                                                                                              | closes **#18**         | one-time manual ref review of ~20 DIN refs; new refs `integration/frame-din-a`, `-b`, `footer-all-pages`                                                           |
| **M3 – Geometry profiles & stationery** | sn-010130-right/left, nf-z-11-001, uk-c5, us-letter-10, a4/letter-digital; regional default; `background.first/rest`; pre-printed; stamp                                                                                                                                                                                         | 0.5.0-dev              | ref per profile (7 small refs, 1 page each); pre-printed ref                                                                                                       |
| **M4 – DSL, data, validation**          | `themes.custom`, `from-data`, leaf types via `display-matcher`, contrast lints/strict, mandatory parts, PDF/A guards, `specimen`                                                                                                                                                                                                 | 0.5.0-rc               | compile-fail tests per message (`typst compile` expected-panic script in `check-pr`); helper/schema coverage test; a docs test per snippet                         |
| **M5 – Parts contract + restyle**       | `(ctx, view, super:)` dispatch for all parts; `restyle`, `themed`; row-level scoped tokens; view v2 for frame parts and bank/payment/signature                                                                                                                                                                                   | 0.5.0-rc               | integration tests `restyle-group`, `part-wrap-signature`                                                                                                           |
| **M6 – Presets & table rewrite**        | `modern`, `minimal`; table/totals renderer rewritten to read tokens directly (drops the 50 params and the spacer-column bugs E6b/E15/E17); line-items view v2                                                                                                                                                                    | **0.5.0 (API locked)** | preset × geometry matrix: classic×din-a, modern×a4-digital, minimal×us-letter (3 refs); all presets zero lints; `--pdf-standard a-3a,ua-1` compile for each preset |
| **M7 – Experimental extras**            | `from-dtcg`, `geometry.reserve` + Swiss QR-bill component, `parts.frame` stabilisation                                                                                                                                                                                                                                           | 0.5.x                  | as they land                                                                                                                                                       |

**Docs** follow the locale trio: `api-reference/theme/index.md` (presets, `.with`, DSL), `theme/tokens.md` (schema tables _generated_ from `schema.typ`), `theme/geometry.md` (profiles, custom formats), `theme/parts.md` (contract, stability tiers), `theme/packages.md` (third-party). Every snippet is registered in `DOCUMENTATION.md` / `TESTING.md` with a `tests/docs/api-theme-*` test.

**Minimum compiler:** stay on **0.14.0**. Nothing here requires 0.15. A later bump would enable `path()` for brand files that reference their own logo, plus `dictionary.map`. It is optional and should be verified on 0.14.0 in M1 CI.

**loom improvements (nice to have, not required):**

1. A deep-merging `apply` variant, or a `scope-merge` mutator on paths.
2. Export `matcher.display` and add an `optional()` descriptor with path-reporting `match`.
3. Fix the labelled-container crash (label hooks on user containers).
4. A version-independent motif key (for example `<invoice-pro>` plus a version field) so that third-party packages _could_ ship motifs.
5. An engine-level "opaque ctx value" convention, which would make the sealing trick official.
6. Fix the `observer` typo and `assert-root`.
