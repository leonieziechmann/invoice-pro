---
sidebar_position: 4
---

# Migrating from 0.4

v0.5.0 replaces the `themes` namespace with `theme`, draws the page frame itself instead of using `letter-pro`, renames `payment-goal` to `payment-terms` and checks the invoice data by default. Most 0.4 documents need two changes: drop the `theme:` argument (or replace it) and rename `payment-goal`.

## Before and After

```typst
// 0.4
#show: invoice.with(
  theme: themes.DIN-5008(form: "B", font: "Inter", hole-mark: false),
  // ..
)
#payment-goal(days: 14)
```

```typst
// 0.5
#show: invoice.with(
  theme: theme.classic.with(
    layout: theme.layout.din-5008-b,
    theme.custom.fonts(body: ("Inter", "Liberation Sans", "Libertinus Serif")),
    theme.custom.marks(punch: none),
  ),
  // sender: .., recipient: .., invoice-nr: ..
)
#payment-terms(days: 14)
```

## Mapping Table

| 0.4                                                             | 0.5                                                                                                                                                                        |
| :-------------------------------------------------------------- | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `theme: themes.DIN-5008()`                                      | Nothing: the default `theme.classic` picks its layout from the sender's country; a German sender gets DIN 5008 form A.                                                     |
| `themes.DIN-5008(form: "B")`                                    | `theme.classic.with(layout: theme.layout.din-5008-b)`                                                                                                                      |
| `font: "Inter"`                                                 | `theme.custom.fonts(body: ("Inter", "Libertinus Serif"))` or `theme.custom.brand(font: ..)`; end the chain in an embedded font.                                            |
| `hole-mark: false`                                              | `theme.custom.marks(punch: none)`                                                                                                                                          |
| `folding-marks: false`                                          | `theme.custom.marks(fold: ())`; no marks at all: `theme.custom.marks(none)`                                                                                                |
| `color-row-odd: a, color-row-even: b`                           | `theme.custom.items-table(zebra: (a, b))`                                                                                                                                  |
| `margin: (..)`                                                  | `theme.custom.page(margin: (..))`. Partial dictionaries fold; the bottom margin is computed by default.                                                                    |
| `footer: [..]` (page 1 only)                                    | `theme.custom.area("footer", parts: ([..], "registration"))`: on every page, and `info` motifs work in it.                                                                 |
| `theme: themes.blank`                                           | `theme: theme.plain`: sender, title and recipient in the flow, the registration block in the footer.                                                                       |
| a native `set page(..)` before `invoice`                        | No longer applies: the theme owns `set page`. Use `theme.custom.page(..)`, `theme.custom.marks(..)` or a [layout](./layouts.md).                                           |
| `themes.blank.with(document: ..)` as a hook in tests            | `theme.resolve(..)` assertions, or a `part(..)` stub that inspects its `view` ([Parts](./parts.md)).                                                                       |
| `.with(line-items: ..)` on a 0.4 theme                          | `theme.custom.wrap("totals", ..)` over `view.totals.rows`, or `theme.custom.part("items-table", ..)`.                                                                      |
| `payment-goal(days: 14)`                                        | `payment-terms(days: 14)`; the parameters are unchanged.                                                                                                                   |
| `bank-details(qr-code: (size: ..))`                             | Unchanged, and it overrides the theme's `theme.custom.bank-details(qr-size: ..)`. Sizes below 20 mm are raised to 20 mm. `qr-code: (display: false)` still hides the code. |
| a missing field printed a placeholder such as `#recipient.name` | A draft marks it inline (‹missing: recipient name›) and lists it on a report page; `validation: "strict"` stops the build ([Validation](../invoice/validation.md)).        |

A theme called with a 0.4 parameter fails with a pointer to this page:

```text
theme `classic`: unexpected named argument(s) `form`. A theme takes patches (e.g. `.with(theme.custom.colors(primary: teal))`) and `layout:` (e.g. `layout: theme.layout.din-5008-b`). `form` is a 0.4 `themes.DIN-5008` parameter; see the migration table in the theme docs.
```

## What Else Changes

| Area           | Change                                                                                                                                                                                                                              |
| :------------- | :---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Default look   | `classic` evolves the 0.4 look: a legal footer on every page, a continuation header on following pages, "Page 1 of 2", a reference line in the bank details and a grouped IBAN. Reference images of your own documents change once. |
| Validation     | `invoice(validation: "draft")` is the default. An incomplete invoice still renders, but with markers, a badge, a watermark and a report page, and without the ZUGFeRD XML. See [Validation](../invoice/validation.md).              |
| Page frame     | invoice-pro no longer depends on `letter-pro`. The layout owns the page: native `set page` rules before `invoice` have no effect.                                                                                                   |
| Unknown keys   | Every patch is checked. A misspelt key stops the build with its path, a did-you-mean hint and the allowed keys.                                                                                                                     |
| Locale strings | New strings: `document.page`, `document.continued-on`, `sections.*`, `line-items.item-id`, `line-items.unit`, `payment.text-due`, `signature.thanks` and the `validation` group. See [Locale API](../locale/index.md).              |
