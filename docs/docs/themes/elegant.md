---
sidebar_position: 4
---

# Elegant

A letter from chambers. Libertinus Serif throughout, one deep ink color for the letterhead, the key labels and the amount to pay, hairlines for every divider and no filled areas. It looks credible in greyscale and costs little to print.

| Preset             | `theme.elegant`                                                                                                          |
| :----------------- | :----------------------------------------------------------------------------------------------------------------------- |
| **Best for**       | law firms, notaries, tax advisers, auditors, consultancies                                                               |
| **Default layout** | the sender's window layout, with `din-5008-b` instead of `din-5008-a` (DE); `us-letter-10` (US); see [Layouts](#layouts) |
| **Output**         | print for a window envelope, and PDF                                                                                     |
| **Fonts**          | Libertinus Serif, embedded in Typst: identical on every machine                                                          |
| **Stability**      | name and default layout stable; the look may still be refined in a minor release                                         |

![A law and tax partnership's fee note in elegant, on DIN 5008 form B](/img/themes/preset-elegant.png)

## Quick Start

Copy this into a `.typ` file and compile it:

```typst
#import "@preview/invoice-pro:0.5.0": *

#show: invoice.with(
  theme: theme.elegant,
  locale: locale.en-de,
  sender: (
    name: "Brenner & Voss Attorneys at Law",
    address: "Jungfernstieg 30",
    city: "20354 Hamburg",
    vat-id: "DE318273645",
    register: [Partnership register Hamburg, PR 1187],
    extra: (Phone: "+49 40 3570 880", Email: "office@brenner-voss.de"),
  ),
  recipient: (
    name: "Halden Shipping GmbH",
    address: "Große Elbstraße 145",
    city: "22767 Hamburg",
  ),
  invoice-nr: "BV-2026-0412",
  subject: "Fee note, Halden v. Norrmar (charter dispute)",
)

#line-items[
  #item(
    [Review of the charter party and correspondence],
    quantity: 6.5,
    unit: unit.hour,
    price: 320,
  )
  #item(
    [Statement of claim, Hamburg Regional Court],
    quantity: 11,
    unit: unit.hour,
    price: 320,
  )
  #item([Travel expenses, hearing in Bremen], price: 186.4)
]

#payment-terms(days: 14)
#bank-details(
  bank: "Hamburger Sparkasse",
  iban: "DE75512108001245126199",
  bic: "SOLADEST600",
)
#signature(name: "Dr. Helena Brenner")
```

## What You Get

- A centered letterhead: the logo above the name, the name in spaced capitals over a short rule, the address on one line.
- The document word centered between hairlines, with the invoice number, place and date on one line below it.
- Labels in small capitals; column heads, "Bill to" and the amount to pay in the ink color.
- A hairline table without stripes, and the amount to pay between a thin rule and an accountant's double rule.
- Bank details as a label grid with the EPC-QR code, and the legal footer on every page.

## Make It Yours

`elegant` works with one brand color, used as ink. Pass it with your logo, and a display face for the letterhead if you have one:

```typst
#show: invoice.with(
  theme: theme.elegant.with(
    theme.custom.brand(
      color: rgb("#5b1f2e"), // one ink color: letterhead, key labels, the payable
      heading-font: ("Cormorant Garamond", "Libertinus Serif"),
      logo: image("logo.svg", alt: "Atelier Nord GmbH"),
    ),
  ),
  // sender: .., recipient: .., invoice-nr: ..
)
```

The default ink is a deep blue (`#1c2a48`). Dark colors work best: the ink is used for text.

## Layouts

The centered letterhead needs room, so for a German sender `elegant` uses DIN 5008 **form B** (a 37 mm letterhead zone) where `classic` uses form A. In every other region it uses the same window layout as `classic`. For form A, pass it explicitly: `theme.elegant.with(layout: theme.layout.din-5008-a)`. The logo then moves beside the name.

## Good to Know

- **Greyscale:** without fills and with dark ink, the invoice survives a black-and-white copy or fax.
- **Fonts:** Libertinus Serif is embedded in Typst, so the invoice looks the same on every machine without installing anything.
- **A premium variant:** [Prestige](./prestige.md) shares the serif grammar of `elegant`, with a dark letterhead band and champagne accents.
