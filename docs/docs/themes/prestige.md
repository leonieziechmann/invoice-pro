---
sidebar_position: 5
---

# Prestige

The invoice as part of the brand. A full-bleed onyx band carries the name in champagne display capitals; on the white page, champagne returns only as fine rules. A Garamond body and a Didone display face give it the feel of a hotel folio or a boutique receipt. Made for few lines and high amounts.

| Preset             | `theme.prestige`                                                                      |
| :----------------- | :------------------------------------------------------------------------------------ |
| **Best for**       | premium brands, boutique hotels, fine dining, fashion, jewellers                      |
| **Default layout** | `a4-band`, `us-letter-band` in the US: a 40 mm full-bleed band, no window             |
| **Output**         | PDF (digital first)                                                                   |
| **Fonts**          | EB Garamond; headings in Playfair Display or Bodoni Moda (fallback: Libertinus Serif) |
| **Stability**      | name and default layout stable; the look may still be refined in a minor release      |

![A boutique hotel's guest folio in prestige, on a4-band](/img/themes/preset-prestige.png)

## Quick Start

Copy this into a `.typ` file and compile it:

```typst
#import "@preview/invoice-pro:0.5.0": *

#show: invoice.with(
  theme: theme.prestige, // digital first: the band prints to the edge of the sheet
  locale: locale.en-at,
  tax-mode: "inclusive", // guest prices include VAT
  sender: (
    name: "Palais Aurelia",
    address: "Seilerstätte 9",
    city: "1010 Vienna",
    vat-id: "ATU73194628",
    register: [Aurelia Hotelbetriebs GmbH · FN 482117 k · Commercial Court Vienna],
    extra: (Phone: "+43 1 512 94 00", Email: "reception@palais-aurelia.at"),
  ),
  recipient: (
    name: "Ms Eleanor Whitcombe",
    address: "14 Cheyne Walk",
    city: "London SW3 5HL, United Kingdom",
  ),
  invoice-nr: "F-2026-0917",
)

#line-items[
  #item(
    [Junior Suite, 17–20 September],
    quantity: 3,
    unit: "nights",
    price: 690,
    tax: 10%,
  )
  #item(
    [Dinner, Restaurant Aurelia],
    quantity: 2,
    unit: "covers",
    price: 124,
    tax: 10%,
  )
  #item([Wine pairing], quantity: 2, unit: "covers", price: 66, tax: 20%)
  #item([Spa, signature treatment], unit: "treatment", price: 185, tax: 20%)
]

#payment-terms()
#bank-details(
  bank: "Erste Bank",
  iban: "AT611904300234573201",
  bic: "GIBAATWWXXX",
)
```

## What You Get

- A dark band across the top of the first page with the logo, the name in spaced display capitals and the address in champagne.
- The document word in a large display face, centered between champagne hairlines, with number, place and date below.
- A hairline table with champagne row rules, labels in small capitals.
- The total between a thin rule and a double rule, the tax shares below it.
- Bank details as a label grid with the EPC-QR code, and the legal footer on every page.

## Make It Yours

`prestige` uses two colors: the band (`color`) and the champagne of its type and rules (`accent`). Your logo sits on the dark band, so give it a light version:

```typst
#show: invoice.with(
  theme: theme.prestige.with(
    theme.custom.brand(
      color: rgb("#12372a"), // the band
      accent: rgb("#d4b483"), // the type on the band and the rules on the page
    ),
    theme.custom.logo(
      image: image("logo.svg", alt: "Atelier Nord GmbH"),
      // a light variant for the dark band; without it the logo gets a light plate
      on-dark: image("logo-light.svg", alt: "Atelier Nord GmbH"),
    ),
  ),
  // sender: .., recipient: .., invoice-nr: ..
)
```

The type on the band is the accent, made legible on the band color. Text in the accent on the white page uses a darker shade (`colors.accent-text`) that reaches a contrast of 4.5:1. To check your own pair, add `theme.custom.checks(min-contrast: 4.5)`; see [Checks](../api-reference/theme/customization.md#checks).

## Good to Know

- **Printing:** most office printers cannot print to the edge of the sheet, so the band is meant for PDF invoices. For print, pass a window layout, for example `theme.prestige.with(layout: theme.layout.din-5008-b)`: the letterhead box of the layout becomes the dark surface, inside the margins.
- **Fonts:** install EB Garamond and Playfair Display (or Bodoni Moda) for the intended look. Without them, everything falls back to Libertinus Serif.
- **Gross prices:** hotels and restaurants usually bill consumers, so the quick start sets `tax-mode: "inclusive"`. See the [B2C guide](../b2c.md).
- **A quieter variant:** [Elegant](./elegant.md) shares the serif grammar of `prestige`, without the band and in one ink color.
