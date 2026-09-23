---
sidebar_position: 1
---

# Customization

Every change to a theme is a **patch**: a positional argument of `.with(..)`. The helpers in `theme.custom` build patches and check their parameter names, so a typo fails where you wrote it.

## Patches and Helpers

Import the helpers into a code block to write several of them at once. Each helper returns a one-element array, so all of them apply:

```typst
#show: invoice.with(
  theme: theme.classic.with({
    import theme.custom: *
    colors(primary: rgb("#1d4ed8"), accent: rgb("#15803d"))
    fonts(body: ("Inter", "Liberation Sans", "Libertinus Serif"))
    items-table(zebra: (none, none))
    totals(fill: rgb("#1d4ed8"))
  }),
  // sender: .., recipient: .., invoice-nr: ..
)
```

A helper inside a false `if` produces `none`, and `none` patches are ignored, so conditional patches need no extra code: `if mode == "print" { stationery("pre-printed") }`.

Every helper parameter defaults to `auto`. The values mean:

| Value            | Effect                                                                                                 |
| :--------------- | :----------------------------------------------------------------------------------------------------- |
| `auto`           | Untouched. Only the parameters you pass are patched.                                                   |
| `none`           | A real value that switches something off, such as `totals(fill: none)` or `marks(none)`.               |
| `reset()`        | Back to the schema default, for example the computed bottom margin: `page(margin: (bottom: reset()))`. |
| `replace(value)` | `value` replaces a dictionary as a whole instead of being merged into it.                              |
| `t => ..`        | In tokens and options: a derivation over the resolved tokens (see [Tokens](#tokens)).                  |

### Helper Reference

| Helper                                                                                                | Patches                         | Parameters                                                                                                             | Tier         |
| :---------------------------------------------------------------------------------------------------- | :------------------------------ | :--------------------------------------------------------------------------------------------------------------------- | :----------- |
| `colors`                                                                                              | tokens                          | `primary`, `on-primary`, `primary-text`, `accent`, `accent-text`, `text`, `text-muted`, `border`, `tint`, `background` | frozen       |
| `fonts`                                                                                               | tokens                          | `body`, `heading`, `label`, `numeric`, `number-width`; `regulated` (0.5.x preview)                                     | frozen       |
| `sizes`                                                                                               | tokens                          | `body`, `small`, `fine`, `large`, `title`                                                                              | frozen       |
| `weights`                                                                                             | tokens                          | `strong`                                                                                                               | frozen       |
| `strokes`                                                                                             | tokens                          | `hairline`, `thin`, `regular`, `thick`                                                                                 | frozen       |
| `spacing`                                                                                             | tokens                          | `small`, `medium`, `leading`                                                                                           | frozen       |
| `radii`                                                                                               | tokens                          | `small`, `medium`                                                                                                      | frozen       |
| `logo`, `title`, `line-items`, `items-table`, `totals`, `bank-details`, `page-number`, `continuation` | options                         | see [Options](#options)                                                                                                | provisional  |
| `row`                                                                                                 | options                         | `fill`; read inside [`themed`](./parts.md#scoped-overrides-themed) only                                                | experimental |
| `page`                                                                                                | layout                          | `paper`, `flipped`, `margin`, `body-top`, `body-gap`, `header-ascent`, `footer-descent`, `footer-clearance`            | frozen       |
| `stationery(value)`                                                                                   | layout                          | `none`, `"pre-printed"` or `(first: content, rest: content)`                                                           | frozen       |
| `marks(none)`, `marks(..)`                                                                            | layout                          | `fold`, `punch`, `left`, `length`, `stroke`                                                                            | frozen       |
| `envelopes(..records)`                                                                                | layout                          | envelope records; replaces the list                                                                                    | stable       |
| `proof(value)`                                                                                        | layout                          | `true`, `false` or an array of envelope names                                                                          | stable       |
| `area(name, ..)`, `area(name, none)`                                                                  | layout                          | the [area fields](./layouts.md#area-fields)                                                                            | frozen       |
| `part(name, renderer)`, `wrap(name, wrapper)`                                                         | parts                           | `(ctx, view) => content`, `(ctx, view, inner) => content`                                                              | frozen       |
| `brand`                                                                                               | tokens, options                 | `color`, `accent`, `font`, `heading-font`, `logo`                                                                      | frozen       |
| `checks`                                                                                              | checks                          | `min-contrast`, `pairs`                                                                                                | stable       |
| `reset()`, `replace(value)`                                                                           | markers                         | –                                                                                                                      | frozen       |
| `from-data(data, assets:)`                                                                            | tokens, options, checks, layout | a parsed brand file                                                                                                    | experimental |

The layout helpers are described on the [Layouts](./layouts.md) page and the part helpers on the [Parts](./parts.md) page.

## `brand()`

The quick path: one or two colors, fonts and a logo. Everything else derives from them.

| Key            | Type                       | Description                                                                                |
| :------------- | :------------------------- | :----------------------------------------------------------------------------------------- |
| `color`        | `color` \| `auto`          | The brand color (`colors.primary`), the seed of the palette.                               |
| `accent`       | `color` \| `auto`          | A second brand color (`colors.accent`) for rules and markers. Defaults to the brand color. |
| `font`         | `str` \| `array` \| `auto` | The body font chain (`fonts.body`). Label, figure and heading fonts derive from it.        |
| `heading-font` | `str` \| `array` \| `auto` | The heading font chain (`fonts.heading`), for the title and headings.                      |
| `logo`         | `content` \| `auto`        | The logo (`logo.image`). Give an `image` an `alt` text; PDF/UA-1 requires it.              |

```typst
#let acme = theme.custom.brand(
  color: rgb("#003a70"),
  accent: rgb("#e2001a"),
  font: ("Source Sans 3", "Liberation Sans", "Libertinus Serif"),
  logo: image("logo.svg", alt: "ACME Maschinenbau GmbH"),
)

#show: invoice.with(
  theme: theme.classic.with(acme),
  // sender: .., recipient: .., invoice-nr: ..
)
```

A brand is an ordinary patch, so the same value works with every preset: `theme.corporate.with(acme)`, `theme.elegant.with(acme)`.

## Tokens

The tokens are the frozen design tier: 30 values that the built-in parts and presets read. A function value is a **derivation** `t => value`. It is evaluated against the resolved tokens (`t.colors.primary`, `t.sizes.body`, …), so a derived value follows when you change its inputs.

| Token                 | Type                            | Default                                   | Used for                                                       |
| :-------------------- | :------------------------------ | :---------------------------------------- | :------------------------------------------------------------- |
| `colors.primary`      | `color`                         | `#1f2937`                                 | the brand color: fills, rails, header fills                    |
| `colors.on-primary`   | `color`                         | black or white, whichever contrasts more  | text on primary fills                                          |
| `colors.primary-text` | `color`                         | `primary`, darkened to 4.5:1              | the brand color used as text (titles, kickers)                 |
| `colors.accent`       | `color`                         | `primary`                                 | the second brand color: rules and ticks                        |
| `colors.accent-text`  | `color`                         | `accent`, darkened to 4.5:1               | the accent used as text                                        |
| `colors.text`         | `color`                         | `black`                                   | body text, marks                                               |
| `colors.text-muted`   | `color`                         | `luma(100)`                               | descriptions, labels, notes, footer, continuation header       |
| `colors.border`       | `color`                         | `black`                                   | table rules                                                    |
| `colors.tint`         | `color` \| `none`               | a light tint of `primary`                 | table stripes and soft fills (`#e2e8f0` for the default color) |
| `colors.background`   | `color`                         | `white`                                   | the page color and the reference for contrast                  |
| `fonts.body`          | `str` \| `array`                | `("Liberation Sans", "Libertinus Serif")` | all text                                                       |
| `fonts.heading`       | `str` \| `array`                | `fonts.body`                              | title and headings                                             |
| `fonts.label`         | `str` \| `array`                | `fonts.body`                              | column headers, section and reference labels                   |
| `fonts.numeric`       | `str` \| `array`                | `fonts.body`                              | amounts, quantities, IBAN, reference numbers                   |
| `fonts.number-width`  | `"tabular"` \| `"proportional"` | `"tabular"`                               | the digit width of amounts                                     |
| `sizes.body`          | `length`                        | `10pt`                                    | body text                                                      |
| `sizes.small`         | `length`                        | `0.85em`                                  | sub-labels, references, page number                            |
| `sizes.fine`          | `length`                        | `7pt`                                     | return address, legal footer; absolute, at least 6 pt          |
| `sizes.large`         | `length`                        | `1.2em`                                   | the grand total                                                |
| `sizes.title`         | `length`                        | `1.4em`                                   | the title                                                      |
| `weights.strong`      | `str` \| `int`                  | `"bold"`                                  | every bold text, the table header                              |
| `strokes.hairline`    | `length`                        | `0.25pt`                                  | fold and punch marks                                           |
| `strokes.thin`        | `length`                        | `0.5pt`                                   | table rules, continuation line                                 |
| `strokes.regular`     | `length`                        | `1pt`                                     | table header rule                                              |
| `strokes.thick`       | `length`                        | `2pt`                                     | totals rule                                                    |
| `spacing.small`       | `length`                        | `0.4em`                                   | cell insets                                                    |
| `spacing.medium`      | `length`                        | `0.6em`                                   | header insets, the gap between the cells of an area            |
| `spacing.leading`     | `length`                        | `0.65em`                                  | paragraph leading of the body and of table cells               |
| `radii.small`         | `length`                        | `2pt`                                     | filled blocks (totals fill, payable bar)                       |
| `radii.medium`        | `length`                        | `4pt`                                     | cards, the logo plate on a dark surface                        |

`fonts.regulated` (default `("Liberation Sans", "Arial", "Helvetica", "Libertinus Serif")`) belongs to the 0.5.x preview of reserved zones and is not frozen. Strokes are thicknesses only; the color is added where a stroke is drawn.

```typst
#show: invoice.with(
  theme: theme.classic.with({
    import theme.custom: *
    colors(
      primary: rgb("#7c2d12"),
      tint: t => t.colors.primary.lighten(92%), // stripes follow the brand color
      border: t => t.colors.primary,
    )
    sizes(body: 9.5pt, title: 1.6em)
    strokes(thick: 1.2pt)
  }),
  // sender: .., recipient: .., invoice-nr: ..
)
```

A derivation must work for any valid token tree. Derivations that depend on each other in a cycle, or that do not settle, panic and name the tokens involved.

## Options

Options are settings of one built-in part. They are **provisional**: a key may still change in a 0.5.x minor release, with a changelog entry. A built-in part reads its own group; `items-table` and `totals` also read `line-items`. A part you [replace](./parts.md) decides for itself which options it honours; a part you wrap keeps them.

| Option                       | Type                                                              | Default                                                 | Description                                                                                                                                                                                      |
| :--------------------------- | :---------------------------------------------------------------- | :------------------------------------------------------ | :----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `logo.image`                 | `none` \| `content`                                               | `none`                                                  | The logo. Give an `image` an `alt` text.                                                                                                                                                         |
| `logo.height`                | `length`                                                          | `14mm`                                                  | Height of the logo.                                                                                                                                                                              |
| `logo.on-dark`               | `auto` \| `none` \| `content`                                     | `auto`                                                  | On a dark surface: `auto` puts the logo on a light plate, content replaces it, `none` keeps it as it is.                                                                                         |
| `title.arrange`              | `"row"` \| `"stack"`                                              | `"row"`                                                 | `"row"`: subject and number, with place and date on the right. `"stack"`: the document word above number and date.                                                                               |
| `title.show-place-date`      | `bool`                                                            | `true`                                                  | Show the place and date next to the title.                                                                                                                                                       |
| `title.color`                | `color`                                                           | `colors.text`                                           | Color of the title text.                                                                                                                                                                         |
| `line-items.discount-color`  | `color`                                                           | `#b22222`                                               | Color of discount and prepayment amounts.                                                                                                                                                        |
| `line-items.surcharge-color` | `color`                                                           | `#333333`                                               | Color of surcharge amounts.                                                                                                                                                                      |
| `line-items.gap`             | `length`                                                          | `0.7em`                                                 | Space between the items table and the totals.                                                                                                                                                    |
| `items-table.zebra`          | `(odd, even)` of `none` \| `color` \| derivation, or a `function` | `(none, colors.tint)`                                   | Row fills. A function `(number) => fill` receives the running number of the line item (1 for the first), the count that decides odd and even. The fill applies per line item, not per table row. |
| `items-table.header-fill`    | `none` \| `color`                                                 | `none`                                                  | Fill of the header row.                                                                                                                                                                          |
| `items-table.header-text`    | `auto` \| `color`                                                 | `auto`                                                  | Header text color; `auto` picks black or white for the fill.                                                                                                                                     |
| `items-table.header-style`   | `dictionary`                                                      | `(:)`                                                   | Extra `set text` arguments of the header, merged key by key; values may be derivations.                                                                                                          |
| `items-table.rule`           | `color`                                                           | `colors.border`                                         | Color of the table rules.                                                                                                                                                                        |
| `items-table.row-rule`       | `none` \| `length` \| `color` \| `stroke`                         | `none`                                                  | A rule between two entries.                                                                                                                                                                      |
| `items-table.row-inset`      | `length`                                                          | `spacing.small * 0.75`                                  | Vertical padding of every entry.                                                                                                                                                                 |
| `items-table.column-order`   | `array` of `str`                                                  | `("quantity", "unit-price", "tax-rate", "total-price")` | Order of the value columns; a column left out is never shown. Whether a listed column shows is decided by [`line-items(show-column: ..)`](../line-items/index.md).                               |
| `items-table.repeat-header`  | `bool`                                                            | `true`                                                  | Repeat the header row on every page.                                                                                                                                                             |
| `totals.width`               | `ratio` \| `relative` \| `length`                                 | `66%`                                                   | Width of the totals block, right-aligned.                                                                                                                                                        |
| `totals.min-width`           | `none` \| `length`                                                | `none`                                                  | A floor for `width` in narrow columns.                                                                                                                                                           |
| `totals.fill`                | `none` \| `color`                                                 | `none`                                                  | Fill behind the totals block (corner radius `radii.small`).                                                                                                                                      |
| `totals.color`               | `auto` \| `color`                                                 | `auto`                                                  | Text color on the fill; `auto` picks black or white.                                                                                                                                             |
| `bank-details.show-qr`       | `bool`                                                            | `true`                                                  | Show the EPC-QR code (EUR only; never for an invalid IBAN).                                                                                                                                      |
| `bank-details.qr-size`       | `auto` \| `length`                                                | `auto`                                                  | Size of the EPC-QR code; `auto` is 25 mm in `classic`. Sizes below 20 mm are raised to 20 mm. A `size` in [`bank-details(qr-code: ..)`](../components.md#bank-details) overrides it.             |
| `page-number.from`           | `auto` \| `int`                                                   | `auto`                                                  | `auto`: every page, as soon as the invoice has more than one. An `int`: the first page with a number.                                                                                            |
| `page-number.format`         | `auto` \| `function`                                              | `auto`                                                  | `(ctx, current, total) => content`; `auto` uses the locale string `document.page`.                                                                                                               |
| `continuation.show-subject`  | `bool`                                                            | `true`                                                  | The header of following pages shows "sender · subject" and the invoice number; `false` shows only the sender.                                                                                    |
| `row.fill`                   | `none` \| `color`                                                 | `none`                                                  | Experimental: fill of the groups and items inside a [`themed`](./parts.md#scoped-overrides-themed) scope.                                                                                        |
| `custom`                     | `dictionary`                                                      | `(:)`                                                   | Free space for third-party parts, under `custom.<package>`; set it with a patch dictionary.                                                                                                      |

```typst
#show: invoice.with(
  theme: theme.classic.with({
    import theme.custom: *
    items-table(
      zebra: (none, none),
      header-fill: rgb("#1f2937"),
      row-rule: 0.5pt + luma(200),
    )
    totals(fill: rgb("#1f2937"), width: 60%)
    title(arrange: "stack")
    page-number(format: (ctx, current, total) => [#current / #total])
    bank-details(qr-size: 30mm)
  }),
  // sender: .., recipient: .., invoice-nr: ..
)
```

`theme.resolve(..).unread-options` lists option groups you changed but that no active built-in part reads, for example `totals` after you replaced the `totals` part.

## Markers: `reset()` and `replace()`

| Marker           | Effect                                                                       | Example                                                                                                           |
| :--------------- | :--------------------------------------------------------------------------- | :---------------------------------------------------------------------------------------------------------------- |
| `reset()`        | Restores the schema default. The only way back to a computed (`auto`) value. | `page(margin: (bottom: reset()))` returns to the computed bottom margin.                                          |
| `replace(value)` | Replaces a dictionary as a whole instead of merging into it.                 | `area("footer", text: replace((size: 8pt)))` drops the text color of the look; `text: (size: 8pt)` would keep it. |

## Merge Rules

All patches, including those of presets and packages, go through one strict merge.

| Patch                                                         | Effect                                                                                               |
| :------------------------------------------------------------ | :--------------------------------------------------------------------------------------------------- |
| a dictionary onto a dictionary                                | Merged key by key. An unknown key panics with its path, a did-you-mean hint and the allowed keys.    |
| a partial `margin` or area `inset`                            | Folds: `(bottom: 35mm)` changes one side; `x`, `y` and `rest` set two or four sides.                 |
| an area anchor (`left`, `right`, `top`, `bottom`)             | Sets the side and clears its partner: setting `left` clears `right`.                                 |
| an area's `text` or `par`                                     | Merged key by key: `text: (size: 9pt)` keeps the fill a look set.                                    |
| an area's `arrange`, `stroke`, `radius`, `rule`, `cell-align` | Replaced as a whole.                                                                                 |
| arrays, scalars, content, functions                           | Replaced.                                                                                            |
| fields onto a group that is `none` (such as `marks`)          | Filled in from a template first: `marks(fold: (105mm, 210mm))` on a digital layout adds marks again. |
| `area(name, ..)` for a name the layout lacks                  | With `place`: adds the area. Without: panics with a did-you-mean hint.                               |
| `area(name, none)`                                            | Removes the area. The removal sticks, unless a later patch with `place` re-creates it.               |

Open maps accept new keys: part names (custom ones need a prefix), `options.custom`, `items-table.header-style`, `checks.pairs` and area names.

## Checks

| Key            | Type                       | Default | Description                                                                                                                                                          |
| :------------- | :------------------------- | :------ | :------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `min-contrast` | `none` \| `int` \| `float` | `none`  | Reports every checked color pair below this contrast ratio (WCAG: 4.5) as a `lint/contrast-*` issue. Issues follow the [validation level](../invoice/validation.md). |
| `pairs`        | `dictionary`               | `(:)`   | Extra pairs to check: `name: t => (foreground, background)` or a literal pair of colors. Merged by name; `none` removes a pair.                                      |

The core checks body and secondary text on the page, the text on primary fills, secondary text on the tint, the title and discount colors, the header text on the header fill, the totals text on the totals fill and the text of every filled area. A part that draws its own color pair should register it in `pairs`.

```typst
#show: invoice.with(
  theme: theme.classic.with(
    theme.custom.brand(color: rgb("#facc15")), // a light brand color
    theme.custom.checks(
      min-contrast: 4.5,
      pairs: (stamp: t => (t.colors.accent-text, t.colors.background)),
    ),
  ),
  // sender: .., recipient: .., invoice-nr: ..
)
```

## Brand Files: `from-data`

:::warning
`theme.custom.from-data` is **experimental**.
:::

`from-data(data, assets: none)` turns a parsed JSON, YAML or TOML dictionary into a patch, so agencies and pipelines can keep brands as data. There is no expression language: a file sets values, and derived values keep deriving from them.

```toml
# brand.toml
[theme.tokens.colors]
primary = "#0b3d91"
accent = "#ffb000"

[theme.tokens.fonts]
body = ["Libertinus Serif"]

[theme.options.logo]
image = "logo.svg"
height = "9mm"

[theme.options.items-table]
zebra = ["none", "none"]

[theme.layout]
margin = { bottom = "35mm" }
```

```typst
#let brand = toml("brand.toml")

#show: invoice.with(
  theme: theme.corporate.with(theme.custom.from-data(
    brand.theme,
    assets: path => image(path, alt: "Nordlicht Studio"),
  )),
  // sender: .., recipient: .., invoice-nr: ..
)
```

| Key      | Type                 | Description                                                                                                                                                                                 |
| :------- | :------------------- | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `data`   | `dictionary`         | Groups `tokens`, `options`, `checks` and `layout`. From `layout` only `paper`, `margin`, `body-top`, `body-gap` and `footer-clearance` are allowed; layouts, areas and stationery are code. |
| `assets` | `none` \| `function` | `path => content`, called for `options.logo.image`. A package cannot open files by path, so the function must be defined in your document.                                                  |

Strings are converted:

| In the file                                       | Becomes                                   |
| :------------------------------------------------ | :---------------------------------------- |
| `"#0b3d91"` (3, 6 or 8 hex digits)                | an `rgb` color                            |
| `"10.5pt"`, `"25mm"`, `"2cm"`, `"1in"`, `"0.4em"` | a length                                  |
| `"66%"`                                           | a ratio                                   |
| `"none"`                                          | `none`                                    |
| `"auto"`                                          | `reset()`: back to the default            |
| any other string                                  | a string (font names, enumeration values) |

Unknown keys fail with the full path, for example ``theme::tokens::colors has unknown key `primry`. Did you mean `primary`?``.

## Color Helpers

| Function                             | Returns                                                                                   |
| :----------------------------------- | :---------------------------------------------------------------------------------------- |
| `theme.contrast(a, b)`               | The WCAG contrast ratio of two colors (`float`, 1 to 21).                                 |
| `theme.on-color(background)`         | `black` or `white`, whichever contrasts more with `background`.                           |
| `theme.legible(fg, bg, target: 4.5)` | `fg`, darkened (on a light `bg`) or lightened (on a dark `bg`) until it reaches `target`. |

The token defaults use them: `colors.on-primary` is `on-color(primary)`, `colors.primary-text` is `legible(primary, background)`.

## Error Messages

| Mistake                                         | Message                                                                                                                                              |
| :---------------------------------------------- | :--------------------------------------------------------------------------------------------------------------------------------------------------- |
| A wrong helper parameter: `colors(primry: red)` | Typst's own error: `unexpected argument: primry`.                                                                                                    |
| A wrong key in a patch dictionary or brand file | ``theme::tokens::colors has unknown key `primry`. Did you mean `primary`? Allowed keys: primary, on-primary, ..``                                    |
| An area the layout lacks: `area("adress", ..)`  | ``theme::layout::areas has no area `adress` in layout `din-5008-a`. Did you mean `address`? .. To ADD an area, give it a `place`.``                  |
| A named argument other than `layout:`           | ``theme `classic`: unexpected named argument(s) `form`. .. `form` is a 0.4 `themes.DIN-5008` parameter; see the migration table in the theme docs.`` |

Mistakes like these always stop the build, whatever the [validation level](../invoice/validation.md): no output could honour them.
