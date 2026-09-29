---
sidebar_position: 10
---

# Boxed

A print-first form. Ruled boxes for the references, the invoice number and date, the payment and the bank details, a heavy title and monospace form labels. It is black on white, and no fill carries meaning, so it survives a cheap laser printer, a photocopy and a fax. Only the rule under the letterhead shows your brand color.

| Preset             | `theme.boxed`                                                                                                                                                                                      |
| :----------------- | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Best for**       | trades and crafts, workshops, construction, anyone who prints, copies or faxes invoices                                                                                                            |
| **Default layout** | a window layout for the sender's country, like `classic`: `din-5008-a` (DE), `din-5008-b` (AT), `sn-010130-right` (CH), `a4-window-right` (FR, IT, ES), `a4-window-left` (GB), `us-letter-10` (US) |
| **Output**         | print for a window envelope, copy and fax, and PDF                                                                                                                                                 |
| **Fonts**          | Liberation Sans (fallback: Libertinus Serif); labels in DejaVu Sans Mono                                                                                                                           |
| **Stability**      | name and default layout stable; the look may still be refined in a minor release                                                                                                                   |

![An electrician's invoice to a private customer in boxed, on DIN 5008 form A](/img/themes/preset-boxed.png)

## Quick Start

Copy this into a `.typ` file and compile it:

```typst
#import "@preview/invoice-pro:0.5.0": *

#show: invoice.with(
  theme: theme.boxed,
  locale: locale.en-de,
  sender: (
    name: "Brandt Electrical GmbH",
    address: "Werkstraße 7",
    city: "34117 Kassel",
    vat-id: "DE287654321",
    register: [Local court Kassel, HRB 18432],
    management: [Managing director: Tobias Brandt],
    extra: (Phone: "+49 561 470 33 90", Emergency: "+49 171 470 33 91"),
  ),
  recipient: (
    name: "Katrin and Jonas Weber",
    address: "Lindenallee 23",
    city: "34131 Kassel",
  ),
  invoice-nr: "R-2026-0317",
  customer-nr: "10482",
  references: (references.customer-nr(), references.vat-id()),
)

#line-items[
  #group([Labour])[
    #item(
      [Electrical installation, master electrician],
      quantity: 6.5,
      unit: unit.hour,
      price: 72,
    )
    #item(
      [Electrical installation, journeyman],
      quantity: 18,
      unit: unit.hour,
      price: 58,
    )
  ]
  #group([Material])[
    #item(
      [Sheathed cable NYM-J 3×1.5 mm²],
      quantity: 120,
      unit: unit.metre,
      price: 1.18,
    )
    #item([Flush-mounted sockets], quantity: 24, unit: unit.piece, price: 6.4)
  ]
  #prepayment(1000, name: "Down payment")
]

#payment-terms(days: 14)
#bank-details(
  bank: "Kasseler Sparkasse",
  iban: "DE75512108001245126199",
  bic: "SOLADEST600",
)
#signature(name: "Tobias Brandt")
```

## What You Get

- The sender's name in a heavy face at the top, above a thick rule in the brand color.
- The recipient in the envelope window, the sender's `extra` details (phone, emergency number) beside it.
- The references in a row of ruled boxes, the title in heavy capitals with the invoice number and date in boxes beside it.
- An items table with fine rules between the rows and no stripes.
- Boxed totals, with the amount to pay in a heavy box.
- The payment sentence in a box, and the bank details as a ruled grid next to a "How to pay" box with the EPC-QR code.
- The legal footer on every page, fold and punch marks.

## Make It Yours

Pass your brand color and logo. The color only draws the letterhead rule, so the form stays readable in black and white:

```typst
#show: invoice.with(
  theme: theme.boxed.with(
    theme.custom.brand(
      color: rgb("#1d4ed8"), // only the letterhead rule: no color carries meaning
      logo: image("logo.svg", alt: "Atelier Nord GmbH"),
    ),
  ),
  // sender: .., recipient: .., invoice-nr: ..
)
```

The default is a signal orange (`#b8400f`).

## Good to Know

- **Private customers:** tradespeople often bill consumers. Set `tax-mode: "inclusive"` for gross prices; see the [B2C guide](../b2c.md).
- **Down payments:** `prepayment(..)` deducts a payment already received and shows the amount still due. See [Partial Payments](../api-reference/line-items/index.md#partial-payments-prepayment).
- **PDF only?** `theme.custom.marks(none)` removes the fold and punch marks.
