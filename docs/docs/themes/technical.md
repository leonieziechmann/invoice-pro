---
sidebar_position: 7
---

# Technical

A spec sheet for invoices. Labels and figures in a monospace font, a fine grid of rules, square corners, section markers and the amount to pay inverted on the brand color. It reads like the documentation your clients already know, and its figures line up digit by digit.

| Preset             | `theme.technical`                                                                                    |
| :----------------- | :--------------------------------------------------------------------------------------------------- |
| **Best for**       | IT freelancers, software houses, engineering and consulting firms, time-and-material billing         |
| **Default layout** | `a4-digital`, `us-letter-digital` in the US: no window, no marks                                     |
| **Output**         | PDF                                                                                                  |
| **Fonts**          | Inter, Liberation Sans or Arial (fallback: Libertinus Serif); labels and figures in DejaVu Sans Mono |
| **Stability**      | name and default layout stable; the look may still be refined in a minor release                     |

![A software house's invoice in technical, on a4-digital](/img/themes/preset-technical.png)

## Quick Start

Copy this into a `.typ` file and compile it:

```typst
#import "@preview/invoice-pro:0.5.0": *

#show: invoice.with(
  theme: theme.technical,
  locale: locale.en-de,
  sender: (
    name: "Brückner & Yildiz Software GmbH",
    address: "Schlesische Straße 26",
    city: "10997 Berlin",
    vat-id: "DE298765431",
    register: [Local court Charlottenburg, HRB 214365 B],
    management: [Managing directors: Jana Brückner, Emre Yildiz],
    extra: (Email: "billing@by-software.de", Web: "by-software.de"),
  ),
  recipient: (
    name: "Hansa Logistik AG",
    address: "Am Speicher XI 4",
    city: "28217 Bremen",
  ),
  invoice-nr: "BY-2026-0917",
  customer-nr: "C-0042",
  project: "DISPATCH-NG",
  references: (references.customer-nr(), references.project()),
)

#line-items[
  #group([Sprint 14, 1–14 September])[
    #item(
      [Backend development],
      description: [REST API v3, OpenAPI spec, contract tests],
      quantity: 38,
      unit: "h",
      price: 115,
    )
    #item([Frontend development], quantity: 26, unit: "h", price: 105)
  ]
  #item(
    [Kubernetes cluster operations, September],
    quantity: 1,
    unit: "month",
    price: 890,
  )
]

#payment-terms(days: 30)
#bank-details(
  bank: "Berliner Sparkasse",
  iban: "DE75512108001245126199",
  bic: "SOLADEST600",
)
```

## What You Get

- The invoice number as the title, under a small "Invoice" label, with the invoice date on the right.
- The recipient and the references as labelled blocks.
- Monospace column heads, quantities, prices and totals: the digits of every amount line up.
- Fine rules between the rows instead of stripes, and square corners throughout.
- The amount to pay inverted on the brand color.
- The payment sentence behind a bar in the brand color, and the bank details under a `// Payment` section marker.

## Make It Yours

Pass your brand color and logo. If you have a monospace font of your own, use it for the labels and figures, and keep the embedded one as the fallback:

```typst
#show: invoice.with(
  theme: theme.technical.with({
    import theme.custom: *
    brand(
      color: rgb("#6d28d9"),
      logo: image("logo.svg", alt: "Atelier Nord GmbH"),
    )
    // labels and figures in your own monospace font, the embedded one as fallback
    fonts(
      label: ("JetBrains Mono", "DejaVu Sans Mono"),
      numeric: ("JetBrains Mono", "DejaVu Sans Mono"),
    )
  }),
  // sender: .., recipient: .., invoice-nr: ..
)
```

The default brand color is a dark petrol (`#155e75`). Dark colors work best: the payable bar carries black or white text, whichever contrasts more.

## Good to Know

- **Timesheets:** groups with their own subtotals, hours with decimals and surcharges on single items (for example a weekend surcharge) all fit the look. See [Line Items](../api-reference/line-items/index.md).
- **Printing for a window envelope:** pass a window layout, for example `theme.technical.with(layout: theme.layout.din-5008-a)`.
- **Fonts:** DejaVu Sans Mono is embedded in Typst, so labels and figures look the same everywhere. Without Inter or Liberation Sans installed, the body text falls back to Libertinus Serif, which still reads like technical documentation.
