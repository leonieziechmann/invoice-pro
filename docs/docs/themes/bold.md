---
sidebar_position: 6
---

# Bold

A poster block in your brand color carries the document word in oversized type and the amount the client pays. Everything else is disciplined: capital labels in a monospace voice, heavy rules over the table and the footer, and the amount to pay repeated on a color bar. All colors derive from one seed, so your brand color restyles the whole invoice.

| Preset             | `theme.bold`                                                                             |
| :----------------- | :--------------------------------------------------------------------------------------- |
| **Best for**       | creative and branding agencies, design, photo and motion studios, event agencies         |
| **Default layout** | `a4-digital`, `us-letter-digital` in the US: no window, no marks                         |
| **Output**         | PDF                                                                                      |
| **Fonts**          | Inter, Arial or Liberation Sans (fallback: Libertinus Serif); labels in DejaVu Sans Mono |
| **Stability**      | name and default layout stable; the look may still be refined in a minor release         |

![A brand and motion studio's invoice in bold, on a4-digital](/img/themes/preset-bold.png)

## Quick Start

Copy this into a `.typ` file and compile it:

```typst
#import "@preview/invoice-pro:0.5.0": *

#show: invoice.with(
  theme: theme.bold,
  locale: locale.en-de,
  sender: (
    name: "Kiln Studio GmbH",
    address: "Lohmühlenstraße 65",
    city: "12435 Berlin",
    vat-id: "DE326598741",
    register: [Local court Charlottenburg, HRB 219876 B],
    extra: (Email: "studio@kiln.studio", Web: "kiln.studio"),
  ),
  recipient: (
    name: "Sonar Audio GmbH",
    address: "Schanzenstraße 22",
    city: "20357 Hamburg",
  ),
  invoice-nr: "KS-2026-044",
)

#line-items[
  #item([Brand strategy and positioning], price: 3200)
  #item(
    [Visual identity system],
    description: [Logo suite, grid, iconography, brand guidelines],
    price: 6500,
  )
  #item(
    [Motion identity: logo animations],
    quantity: 3,
    unit: unit.piece,
    price: 850,
  )
  #discount([Package discount], amount: 5%)
]

#payment-terms(days: 14)
#bank-details(
  bank: "GLS Bank",
  iban: "DE75512108001245126199",
  bic: "SOLADEST600",
)
```

## What You Get

- The sender's name large at the top, the address on one line.
- The poster block: invoice number, place and date, the document word in oversized type, and the amount due with its currency.
- Capital monospace labels for "Bill to", the column heads and the bank details.
- Heavy rules over the items table and the footer, stripes in a light tint of the brand color.
- The amount to pay again on a bar of the brand color, below the totals.
- Page numbers as "1 / 2", only on invoices with more than one page.

## Make It Yours

One color is all `bold` needs:

```typst
#show: invoice.with(
  theme: theme.bold.with(
    theme.custom.brand(
      color: rgb("#e4572e"), // the poster block, the stripes and the payable bar
      logo: image("logo.svg", alt: "Atelier Nord GmbH"),
    ),
  ),
  // sender: .., recipient: .., invoice-nr: ..
)
```

The default is an electric ultramarine (`#2b2bd9`). Saturated colors work best. The text on the poster block turns black or white, whichever contrasts more with your color.

## Good to Know

- **Printing for a window envelope:** pass a window layout, for example `theme.bold.with(layout: theme.layout.din-5008-a)`. The poster block stays in the flow; the recipient moves into the window.
- **Light brand colors:** add `theme.custom.checks(min-contrast: 4.5)` to be told when a color pair is hard to read. See [Checks](../api-reference/theme/customization.md#checks).
- **Labels:** the label font, DejaVu Sans Mono, is embedded in Typst, so the labels look the same everywhere. Install Inter for the intended body text.
