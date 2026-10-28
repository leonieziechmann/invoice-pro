---
sidebar_position: 8
---

# Soft

Warm and friendly. Serif headings, rounded cards in a pastel tint of your brand color, the invoice number and date in pills, dotted rules and a "How to pay" card. Made for businesses whose clients are people rather than accounts payable departments.

| Preset             | `theme.soft`                                                                           |
| :----------------- | :------------------------------------------------------------------------------------- |
| **Best for**       | cafés, bakeries, practices, studios, small retail, B2C                                 |
| **Default layout** | `a4-digital`, `us-letter-digital` in the US: no window, no marks                       |
| **Output**         | PDF                                                                                    |
| **Fonts**          | Segoe UI or Liberation Sans (fallback: Libertinus Serif); headings in Libertinus Serif |
| **Stability**      | name and default layout stable; the look may still be refined in a minor release       |

![A café and bakery's catering invoice in soft, on a4-digital](/img/themes/preset-soft.png)

## Quick Start

Copy this into a `.typ` file and compile it:

```typst
#import "@preview/invoice-pro:0.5.0": *

#show: invoice.with(
  theme: theme.soft,
  locale: locale.en-de,
  tax-mode: "inclusive", // consumer prices include VAT
  sender: (
    name: "Lindenblatt Bakery",
    address: "Lindenstraße 8",
    city: "79098 Freiburg",
    vat-id: "DE287654321",
    extra: (Phone: "+49 761 555 38 20", Web: "lindenblatt.de"),
  ),
  recipient: (
    name: "Katharina Sommer",
    address: "Wiesenweg 14",
    city: "79100 Freiburg",
  ),
  invoice-nr: "2026-0381",
  subject: "Catering, birthday brunch on 12 September",
)

#line-items[
  #item([Brunch buffet], quantity: 24, unit: "guests", price: 18.5, tax: 7%)
  #item(
    [Raspberry cream cake],
    quantity: 2,
    unit: unit.piece,
    price: 42,
    tax: 7%,
  )
  #item(
    [Coffee and tea bar],
    quantity: 24,
    unit: "guests",
    price: 3.9,
    tax: 19%,
  )
  #discount([Regular customer discount], amount: 5%)
]

#payment-terms(days: 14)
#bank-details(
  bank: "Sparkasse Freiburg",
  iban: "DE75512108001245126199",
  bic: "SOLADEST600",
)
#signature(name: "Marie Lindner")
```

## What You Get

- The sender's name in the brand color at the top right, the logo on the left.
- The document word as a serif heading, the invoice number and date in two pills.
- The items in a rounded card with a tinted serif header and dotted rules between the rows.
- The totals in a tinted card, the amount to pay in the brand color.
- The bank details and the EPC-QR code in a "How to pay" card.
- The signature in the brand color, and a centered footer under a dotted rule.

## Make It Yours

Pass your brand color and logo; the pastel cards, the pills and the rules follow the color. The corner radii set how round the cards are:

```typst
#show: invoice.with(
  theme: theme.soft.with({
    import theme.custom: *
    brand(
      color: rgb("#2f6f5e"), // the pastel cards and the pills follow the brand color
      logo: image("logo.svg", alt: "Atelier Nord GmbH"),
    )
    radii(small: 3pt, medium: 6pt) // less rounded cards
  }),
  // sender: .., recipient: .., invoice-nr: ..
)
```

The default is a warm terracotta (`#9c3d26`). Mid to dark colors work best: the brand color is also used for text, and `soft` darkens it where needed to keep it legible on the tinted cards.

## Good to Know

- **Consumers:** private clients expect gross prices, so the quick start sets `tax-mode: "inclusive"`. See the [B2C guide](../b2c.md) for what a consumer invoice must contain.
- **Printing for a window envelope:** pass a window layout, for example `theme.soft.with(layout: theme.layout.din-5008-a)`.
- **Fonts:** the headings use Libertinus Serif, which is embedded in Typst, so the voice of the invoice is the same everywhere.
