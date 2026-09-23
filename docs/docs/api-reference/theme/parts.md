---
sidebar_position: 3
---

# Parts

A part is a renderer for one piece of output: the recipient, the title, the totals, the bank details. The layout places frame parts in its [areas](./layouts.md#areas); the components (`line-items`, `bank-details`, `payment-terms`, `signature`) call the body parts. You can wrap a part, replace it, or add parts of your own.

## The Part Contract

| Item         | Contract                                                                                                            |
| :----------- | :------------------------------------------------------------------------------------------------------------------ |
| Renderer     | `(ctx, view) => content`                                                                                            |
| Wrapper      | `(ctx, view, inner) => content`; `inner(ctx, view)` renders the part it wraps.                                      |
| `ctx.theme`  | The resolved theme: `tokens`, `options`, `layout`, `env`, … (see [Testing a Theme](#testing-a-theme-themeresolve)). |
| `ctx.locale` | The locale: `strings`, `format`, `currency`, …                                                                      |
| `view`       | The data of this part (see [Views](#views)).                                                                        |

Every other key of `ctx` is internal and may change without notice.

```typst
#show: invoice.with(
  theme: theme.classic.with({
    import theme.custom: *
    part("signature", (ctx, view) => [— #view.name]) // replace
    wrap("bank-details", (ctx, view, inner) => block(
      fill: ctx.theme.tokens.colors.tint,
      inset: 8pt,
      inner(ctx, view),
    )) // wrap
    part("totals", (ctx, view) => {
      // eject: start from the built-in renderer, then change it
      set text(fill: ctx.theme.tokens.colors.primary)
      theme.parts.totals(ctx, view)
    })
  }),
  // sender: .., recipient: .., invoice-nr: ..
)
```

| Helper                 | Effect                                                                                                         |
| :--------------------- | :------------------------------------------------------------------------------------------------------------- |
| `part(name, renderer)` | Replaces the renderer. `part(name, none)` hides an optional part; for a required part that is a `theme` issue. |
| `wrap(name, wrapper)`  | Wraps the renderer that is active so far, keeping its options.                                                 |

Wraps stack in patch order: the preset's look first, then your patches, then [`themed`](#scoped-overrides-themed) scopes from the outside in. `part(..)` in any layer drops the wraps below it.

A part must follow these rules:

- A required part must render something (see [Built-in Parts](#built-in-parts)).
- A part reads only `ctx.theme`, `ctx.locale` and `view`. Output that depends on the page reads `view.page`.
- A replaced `items-table` must create a real `table.header`, so the reading order of PDF/UA holds. The built-in table keeps the totals together with its last row; after a replaced table, the totals simply follow it.
- A part that draws a color pair of its own should register it in [`checks.pairs`](./customization.md#checks).

## Built-in Parts

Part names are frozen. Custom parts need a package prefix, such as `acme/rail`; names without a prefix are reserved for future built-ins.

| Part             | Renders                                                                                 | Called by                                  | Requirement                                     |
| :--------------- | :-------------------------------------------------------------------------------------- | :----------------------------------------- | :---------------------------------------------- |
| `title`          | Subject, invoice number, place and date.                                                | frame                                      | role `title`; must show the number and the date |
| `recipient`      | The recipient's name and address.                                                       | frame                                      | role `recipient`                                |
| `sender`         | The sender's name and address.                                                          | frame                                      | role `supplier`                                 |
| `company`        | The sender's name and address as a footer block.                                        | frame                                      | role `supplier`                                 |
| `return-address` | The one-line sender address above the window.                                           | frame                                      | role `supplier`                                 |
| `registration`   | Company register, management, VAT ID and tax number.                                    | frame                                      | role `tax-id`                                   |
| `references`     | The references as a row.                                                                | frame                                      | role `tax-id`                                   |
| `reference-list` | The references as a label/value list.                                                   | frame                                      | role `tax-id`                                   |
| `logo`           | The logo (`logo` options).                                                              | frame                                      | –                                               |
| `sender-details` | The sender's `extra` pairs, such as phone and e-mail.                                   | frame                                      | –                                               |
| `contact`        | The sender's `extra` pairs as a footer block.                                           | frame                                      | –                                               |
| `bank-account`   | IBAN (grouped in fours) and BIC as a footer block.                                      | frame                                      | –                                               |
| `page-number`    | "Page 1 of 2" (`page-number` options, locale string `document.page`).                   | frame                                      | –                                               |
| `continuation`   | The header of following pages: sender, subject and invoice number.                      | frame                                      | –                                               |
| `marks`          | Fold and punch marks from the layout.                                                   | frame                                      | –                                               |
| `qr-bill`        | The Swiss QR-bill placeholder (0.5.x preview; only hosted by `reserve-qr-bill`).        | frame                                      | –                                               |
| `line-items`     | The composite: `items-table`, then `totals`.                                            | `line-items` component                     | required                                        |
| `items-table`    | The table of items.                                                                     | the `line-items` part                      | required                                        |
| `totals`         | The totals block.                                                                       | the `line-items` part                      | required                                        |
| `notes`          | Tax statements, shared unit, quantity and date, and legal notes such as tax exemptions. | `line-items` component, after `line-items` | required while legal notes are needed           |
| `bank-details`   | Bank details with the EPC-QR code.                                                      | `bank-details` component                   | –                                               |
| `payment-terms`  | The payment sentence.                                                                   | `payment-terms` component                  | –                                               |
| `signature`      | Closing and signature.                                                                  | `signature` component                      | –                                               |

The roles are explained in [What Every Invoice Layout Must Host](./layouts.md#what-every-invoice-layout-must-host). `company`, `contact`, `registration` and `bank-account` take the text color of their area and never hyphenate. `notes` is called outside the `line-items` part, so replacing `line-items` cannot drop the legal notes.

Compliance output never lives in a part: PDF metadata, the language, the `factur-x.xml` attachment, the decision which legal notes are required, the suppression of 0 % tax rows and the EPC-QR payload are produced by the core before any part runs.

## Views

A part receives the data it needs in `view`. Fields in **bold** are frozen; all others are provisional and may change in a 0.5.x minor release.

### Frame View

The frame parts (all parts called by the frame) receive the same record:

| Field                                       | Type                                                  | Description                                                                                                                                                             |
| :------------------------------------------ | :---------------------------------------------------- | :---------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **`document.kind`**                         | `str`                                                 | The document kind; `"invoice"` in 0.5.0.                                                                                                                                |
| **`document.title`**                        | `str` \| `content`                                    | The document word from the locale (`strings.document.invoice`).                                                                                                         |
| **`document.subject`**                      | `str` \| `content`                                    | The subject, without the invoice number.                                                                                                                                |
| **`document.number`**                       | `str` \| `content` \| `none`                          | The invoice number.                                                                                                                                                     |
| **`document.date`**                         | `(value: datetime, text: str)`                        | The invoice date and its formatted text.                                                                                                                                |
| `document.place`                            | `str` \| `none`                                       | The sender's city.                                                                                                                                                      |
| **`sender.name`**, **`sender.lines`**       | `content`, `array`                                    | The name and the address lines. The other normalized party fields (`vat-id`, `tax-nr`, `register`, `management`, `extra`, `country`, `name-inline`, …) are provisional. |
| **`recipient.name`**, **`recipient.lines`** | `content`, `array`                                    | As for the sender.                                                                                                                                                      |
| **`currency`**                              | `str`                                                 | The ISO 4217 currency code.                                                                                                                                             |
| `references`                                | `array`                                               | `(label, value)` pairs of the reference block.                                                                                                                          |
| `bank`                                      | `dictionary` \| `none`                                | The data of the `bank-details` component.                                                                                                                               |
| `totals`                                    | `dictionary`                                          | `net`, `gross`, `due` and `prepaid`, each `(value, text)`.                                                                                                              |
| `payment`                                   | `dictionary`                                          | `days` of the payment terms and `due`, the due date as `(value, text)` or `none`.                                                                                       |
| **`page`**                                  | `(current: int, total: int)` \| `none`                | Set in headers, footers and layers. `total` does not count the draft report page.                                                                                       |
| **`layout`**                                | `(name, width, height)`                               | The active layout.                                                                                                                                                      |
| **`area`**                                  | `(name, place, width, height, window, fill, surface)` | The hosting area. `window`: a fixed area that hosts `recipient`; `surface`: the color behind the content.                                                               |
| `marks`                                     | `dictionary` \| `none`                                | The resolved marks of the layout.                                                                                                                                       |

In a draft, a missing required field (the invoice number, a name, an address, the sender's tax ID) arrives as an inline marker in the same field, so every theme shows it.

### Body Views

| Part                                           | Fields                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           |
| :--------------------------------------------- | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `line-items`, `items-table`, `totals`, `notes` | `totals.rows`: an array of `(kind, label, value: (value, text), emphasis, rate, name, marker, payable)` in the legal order of the tax mode, with 0 % tax rows removed. `kind` is one of `"subtotal"`, `"discount"`, `"surcharge"`, `"net-total"`, `"tax"`, `"total"`, `"prepayment"`, `"amount-due"`. `totals.payable`: the row the recipient pays. Also `items`, `entries`, `taxes`, `discounts`, `surcharges`, `prepayments`, `total`, `layout-information`, `tax-mode`, `tax-exempt-small-biz`; `notes` also gets `required`. |
| `bank-details`                                 | `iban`: `(value, text, valid)`, the text grouped in fours; `payment-reference`; `show-reference`; `qr`: `none` or `(size) => content` (EUR only, black on white, at least 20 mm, never for an invalid IBAN; a `size` given to `bank-details(qr-code: ..)` wins over the argument); `sender`: `(name, bank, iban, bic)`; `reference`; `text`.                                                                                                                                                                                     |
| `payment-terms`                                | `amount`: `(value, text)`; `amount-kind`: `"total"` or `"amount-due"` (after prepayments); `deadline`: the deadline phrase; `days`; `date`; `total`.                                                                                                                                                                                                                                                                                                                                                                             |
| `signature`                                    | `name`, `signature`.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             |

A replacement for the payment sentence, built from the view:

```typst
#let pay-card(ctx, view) = {
  let fill = ctx.theme.tokens.colors.accent.lighten(88%)
  block(fill: fill, inset: 1em, width: 100%)[
    Please pay *#view.amount.text* #view.deadline.
  ]
}

#show: invoice.with(
  locale: locale.en-de,
  theme: theme.corporate.with(theme.custom.part("payment-terms", pay-card)),
  // sender: .., recipient: .., invoice-nr: ..
)
```

## Custom Parts and Areas

An area's `parts` may hold part names, content and functions `(ctx, view) => content`. Content is evaluated with the invoice data, so [`info`](../components.md#info-module) motifs work in it:

```typst
#show: invoice.with(
  theme: theme.classic.with(
    layout: theme.layout.us-letter-10,
    theme.custom.area("footer", arrange: (columns: (1fr, 1fr, 1fr)), parts: (
      [*Remit to:* #info.sender.name, PO Box 12, Austin TX],
      [billing\@acme.com],
      "registration",
    )),
  ),
  // sender: .., recipient: .., invoice-nr: ..
)
```

A named custom part needs a package prefix and must be hosted by an area. A new area needs a `place`:

```typst
#let paid(ctx, view) = {
  let accent = ctx.theme.tokens.colors.accent
  rotate(-12deg, block(
    stroke: 2pt + accent,
    inset: 6pt,
    radius: ctx.theme.tokens.radii.medium,
    text(size: 18pt, weight: "bold", fill: accent)[PAID],
  ))
}

#show: invoice.with(
  theme: theme.classic.with({
    import theme.custom: *
    part("acme/paid", paid)
    area(
      "stamp",
      place: "foreground",
      pages: "first",
      left: 140mm,
      top: 110mm,
      parts: ("acme/paid",),
    )
    colors(accent: rgb("#15803d"))
    checks(pairs: (paid-stamp: t => (t.colors.accent, t.colors.background)))
  }),
  // sender: .., recipient: .., invoice-nr: ..
)
```

A part name without a prefix, or a registered part that no area hosts, stops the build with a message that says so.

## Built-in Renderers: `theme.parts`

`theme.parts` holds every built-in renderer as a function, for example `theme.parts.totals(ctx, view)`. Call one inside your own part to start from the default output and change it (the "eject" in the first example on this page). The module contains `logo`, `sender`, `sender-details`, `return-address`, `recipient`, `references`, `reference-list`, `title`, `company`, `contact`, `registration`, `bank-account`, `page-number`, `continuation`, `marks`, `qr-bill`, `line-items`, `items-table`, `totals`, `notes`, `bank-details`, `payment-terms` and `signature`.

The preset looks replace many of these renderers. `theme.parts` always holds the renderers of `classic`.

## Scoped Overrides: `themed`

:::warning
`themed` is **experimental**.
:::

`themed(..patches)[body]` re-themes a part of the body with the same patches as `theme.custom`. Derived tokens re-derive inside the scope.

```typst
#line-items[
  #group([Phase 1])[#item([Concept], price: 1800)]
  #themed(theme.custom.row(fill: rgb("#fef3c7")))[
    #group([Phase 2 (optional)])[
      #item([Artwork], price: 650)
      #item([Print], price: 240)
    ]
  ]
]

#themed({
  import theme.custom: *
  colors(primary: rgb("#b91c1c")) // the tint re-derives inside the scope
  wrap("bank-details", (ctx, view, inner) => block(
    fill: ctx.theme.tokens.colors.tint,
    inset: 8pt,
    inner(ctx, view),
  ))
})[#bank-details(bank: "Hamburger Sparkasse", iban: "DE75512108001245126199")]
```

| Allowed in `themed`                               | Rejected (panics)                                                                                                                            |
| :------------------------------------------------ | :------------------------------------------------------------------------------------------------------------------------------------------- |
| tokens, options, checks, body parts, `row(fill:)` | layout patches, frame parts, and the frame options `logo`, `title`, `page-number`, `continuation`: the page frame is drawn once per document |

`theme.custom.row(fill:)` is read by the `group` and `item` components inside the scope. Issues found in a scope, such as a contrast problem, follow the validation level; in a draft their ids start with `themed/`.

## Theme Packages

A theme package ships a layout dictionary, prefixed parts and patch dictionaries. It imports nothing from invoice-pro, so it works with any invoice-pro version that supports the schema it uses. A wrap is written as the dictionary `("__invoice-pro-wrap__": wrapper)`, which is what `theme.custom.wrap` produces.

```typst
// @preview/acme-theme: lib.typ - no invoice-pro import
#let sidebar-a5 = (
  name: "acme-sidebar-a5",
  paper: "a5",
  flipped: true,
  marks: none,
  margin: (top: 12mm, left: 72mm, right: 12mm), // bottom: computed from the footer
  areas: (
    rail: (
      place: "background",
      pages: "all",
      left: 0mm,
      top: 0mm,
      width: 60mm,
      height: 100%,
      stationery: true,
      fill: t => t.colors.primary,
      inset: 8mm,
      text: (fill: t => t.colors.on-primary, size: 8.5pt),
      parts: ("acme/rail", "sender"),
    ),
    title: (place: "before", parts: ("title",)),
    address: (place: "before", parts: ("recipient",)),
    page-number: (place: "footer", parts: ("page-number",), align: right),
    footer: (place: "footer", parts: ("registration",)),
  ),
)

#let rail(ctx, view) = text(size: 16pt, weight: "bold")[ACME]

#let patch = (
  parts: (
    "acme/rail": rail,
    signature: (
      "__invoice-pro-wrap__": (ctx, view, inner) => {
        inner(ctx, view)
        text(size: 7pt)[Digitally issued.]
      },
    ),
  ),
  tokens: (colors: (primary: rgb("#7c3aed")), sizes: (body: 9pt)),
  options: (items-table: (zebra: (none, none)), totals: (width: 60%)),
)
```

Users combine it with any preset:

```typst
#import "@preview/invoice-pro:0.4.2": *
#import "@preview/acme-theme:0.1.0" as acme

#show: invoice.with(
  theme: theme.classic.with(acme.patch, layout: acme.sidebar-a5),
  // sender: .., recipient: .., invoice-nr: ..
)
```

The package lists only the areas it uses; the standard areas it leaves out become empty stubs. Its CI can check the theme against the published invoice-pro with [`theme.resolve`](#testing-a-theme-themeresolve):

```typst
#let _ = theme.resolve(theme.classic.with(acme.patch, layout: acme.sidebar-a5))
```

## Testing a Theme: `theme.resolve`

`theme.resolve(theme, env: .., validation: ..)` evaluates a lazy theme outside an invoice, for unit tests and package CI.

| Key          | Type                              | Description                                                                                                                                                            |
| :----------- | :-------------------------------- | :--------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `theme`      | `function`                        | A lazy theme, such as `theme.classic.with(..)`.                                                                                                                        |
| `env`        | `dictionary`                      | The document environment. Defaults to `(kind: "invoice", lang: "de", region: "de", e-invoice: none)`; `region` selects the layout for `layout: auto`.                  |
| `validation` | `none` \| `"draft"` \| `"strict"` | `"strict"` (default) panics when the theme has issues, so a CI job fails. `"draft"` and `none` return them in `issues`. `--input invoice-pro-validation` overrides it. |

It returns the resolved theme, the same dictionary parts see as `ctx.theme`:

| Key              | Content                                                                |
| :--------------- | :--------------------------------------------------------------------- |
| `meta`           | `(name, schema)`: the preset name and the schema version.              |
| `env`            | The environment the theme was resolved for.                            |
| `layout`         | The resolved layout, with every area as a full record.                 |
| `parts`          | Part name → renderer (or `none`).                                      |
| `tokens`         | All 30 tokens, resolved.                                               |
| `options`        | All options, resolved.                                                 |
| `checks`         | The check settings.                                                    |
| `requirements`   | The roles and parts the document kind requires.                        |
| `issues`         | The theme's own findings, such as contrast problems or a missing role. |
| `unread-options` | Option groups you changed that no active built-in part reads.          |

```typst
#let company = theme.classic.with(
  theme.custom.brand(color: rgb("#0f766e")),
  theme.custom.checks(min-contrast: 4.5),
)

#let t = theme.resolve(company)
#assert.eq(t.tokens.colors.primary, rgb("#0f766e"))
#assert.eq(t.layout.name, "din-5008-a")
#assert.eq(t.issues, ())

#let us = theme.resolve(company, env: (
  kind: "invoice",
  lang: "en",
  region: "us",
  e-invoice: none,
))
#assert.eq(us.layout.name, "us-letter-10")
```
