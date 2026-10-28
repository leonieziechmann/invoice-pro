---
sidebar_position: 3
---

# Corporate

A two-color brand system for larger companies. The deep primary color carries the structure: the filled table header, the payable bar, the serif display title and the section labels. The accent color only draws rules and ticks. A tinted brand rail on the left holds the supplier's identity and all legal data, so the body stays free for what accounts payable needs: order numbers, delivery notes and the amount to pay.

| Preset             | `theme.corporate`                                                                |
| :----------------- | :------------------------------------------------------------------------------- |
| **Best for**       | larger companies and holdings, purchase-order driven B2B, many references        |
| **Default layout** | `a4-sidebar`, `us-letter-sidebar` in the US: a 56 mm brand rail, no window       |
| **Output**         | PDF                                                                              |
| **Fonts**          | Liberation Sans (fallback: Libertinus Serif); headings in Libertinus Serif       |
| **Stability**      | name and default layout stable; the look may still be refined in a minor release |

![A manufacturer's invoice to a logistics holding in corporate, on a4-sidebar](/img/themes/preset-corporate.png)

## Quick Start

Copy this into a `.typ` file and compile it:

```typst
#import "@preview/invoice-pro:0.5.0": *

#show: invoice.with(
  theme: theme.corporate,
  locale: locale.en-de,
  sender: (
    name: "Vossberg Drive Systems AG",
    address: "Am Stadtholz 44",
    city: "33609 Bielefeld",
    vat-id: "DE124578903",
    register: [Local court Bielefeld, HRB 38127],
    management: [Executive board: Dr. K. Vossberg, A. Nwosu-Lange],
    extra: (Phone: "+49 521 9860 0", Email: "receivables@vossberg.de"),
  ),
  recipient: (
    name: "Nordhafen Logistics Holding GmbH",
    address: "Accounts Payable · Kattwykdamm 12",
    city: "21129 Hamburg",
  ),
  invoice-nr: "VA-2026-004817",
  customer-nr: "D-10442",
  order-nr: "PO 7300051962",
  // the purchase-order data becomes a labelled details table
  references: (
    references.customer-nr(),
    references.order-nr(),
    references.due-date(),
  ),
)

#line-items[
  #group([Conveyor drives])[
    #item(
      [Helical gear motor VG 90, 2.2 kW],
      quantity: 12,
      unit: unit.piece,
      price: 1284,
    )
    #item(
      [Frequency inverter VF 400, 3 kW],
      quantity: 12,
      unit: unit.piece,
      price: 896,
    )
  ]
  #item([Commissioning and acceptance test], unit: unit.lump-sum, price: 2350)
  #discount([Framework volume rebate], amount: 3%)
]

#payment-terms(days: 30)
#bank-details(
  bank: "Deutsche Bank AG",
  iban: "DE89370400440532013000",
  bic: "DEUTDEDBBIE",
)
```

## What You Get

- A brand rail with the logo, the sender, the contact details, the register entry, the VAT ID and the bank account.
- A display title in the heading font, with the invoice number and date as key facts beside it.
- The recipient under "Bill to", and the [references](../api-reference/invoice/references.md) as a labelled details table.
- An items table with a header filled in the primary color and quiet stripes.
- The amount to pay in a bar of the primary color.
- Payment and bank details as labelled sections, each marked with an accent tick.

## Make It Yours

`corporate` is built for two brand colors. Pass both, and your logo:

```typst
#show: invoice.with(
  theme: theme.corporate.with(
    theme.custom.brand(
      color: rgb("#003a70"), // table header, payable bar, title, section labels
      accent: rgb("#e2001a"), // rules and ticks only, never text
      logo: image("logo.svg", alt: "Atelier Nord GmbH"),
    ),
  ),
  // sender: .., recipient: .., invoice-nr: ..
)
```

The default colors are a deep navy (`#15325b`) and brass (`#c9972c`). A dark primary color works best: the table header and the payable bar carry text in black or white, whichever contrasts more.

## Good to Know

- **Mailing the invoice?** The sidebar layout has no envelope window. Pass a window layout, for example `theme.corporate.with(layout: theme.layout.din-5008-a)`: the look stays, and the legal data moves from the rail to the footer.
- **Many references:** customer number, order number, delivery note, contract and due date all fit the details table. See [References](../api-reference/invoice/references.md).
- **Printing:** the rail runs to the edge of the sheet, which most office printers cannot print. The sidebar layout is meant for PDF invoices.
