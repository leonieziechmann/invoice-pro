---
sidebar_position: 9
---

# Compact

Maximum density for long invoices. 8.5 pt type, an item number column and a unit column, a filled header that repeats on every page, one group per delivery note and boxed totals. The whole head of the invoice, from the sender to the invoice number, fits in a single row, so the first page is mostly items.

| Preset             | `theme.compact`                                                                                   |
| :----------------- | :------------------------------------------------------------------------------------------------ |
| **Best for**       | wholesale and distribution, B2B supply, collective invoices, invoices with 40 to 80 lines         |
| **Default layout** | `a4-dense`, `us-letter-dense` in the US: one header row, no window                                |
| **Output**         | PDF and print                                                                                     |
| **Fonts**          | Inter, Arial or Liberation Sans (fallback: Libertinus Serif)                                      |
| **Stability**      | name and default layout stable; the look (and its layout) may still be refined in a minor release |

![A wholesaler's collective invoice over three delivery notes in compact, on a4-dense](/img/themes/preset-compact.png)

## Quick Start

Copy this into a `.typ` file and compile it:

```typst
#import "@preview/invoice-pro:0.5.0": *

#show: invoice.with(
  theme: theme.compact,
  locale: locale.en-de,
  sender: (
    name: "Nordwerk Industrial Supply GmbH",
    address: "Billstraße 80",
    city: "20539 Hamburg",
    vat-id: "DE814562370",
    register: [Local court Hamburg, HRB 90215],
    extra: (Phone: "+49 40 780 44 0", Email: "invoices@nordwerk.de"),
  ),
  recipient: (
    name: "Elbe Metal Works GmbH",
    address: "Neuhöfer Straße 23",
    city: "21107 Hamburg",
  ),
  invoice-nr: "SR-2026-09-118",
  customer-nr: "K-20931",
  references: (references.customer-nr(), references.vat-id()),
)

// one group per delivery note; item-id fills the item number column
#line-items[
  #group([Delivery note LS-26-4471, 3 September])[
    #item(
      [Hex bolt DIN 933 M8×16, 8.8, zinc],
      item-id: (seller: "10-40816"),
      quantity: 12,
      unit: "pk",
      price: 6.9,
    )
    #item(
      [Hex nut DIN 934 M8, zinc],
      item-id: (seller: "11-20008"),
      quantity: 10,
      unit: "pk",
      price: 5.8,
    )
    #item(
      [Heavy-duty anchor 10/10],
      item-id: (seller: "14-11008"),
      quantity: 50,
      unit: unit.piece,
      price: 2.38,
    )
  ]
  #group([Delivery note LS-26-4539, 10 September])[
    #item(
      [Cutting disc INOX 125 × 1.0 mm],
      item-id: (seller: "20-00135"),
      quantity: 100,
      unit: unit.piece,
      price: 1.29,
    )
    #item(
      [Steel wire rope 5 mm, 7×19, zinc],
      item-id: (seller: "50-12050"),
      quantity: 150,
      unit: unit.metre,
      price: 0.92,
    )
  ]
  #discount([Volume discount], amount: 3%)
]

#payment-terms(days: 30)
#bank-details(
  bank: "Hamburger Sparkasse",
  iban: "DE75512108001245126199",
  bic: "SOLADEST600",
)
```

## What You Get

- One header row: the logo and the sender, the recipient, the references and the title with number and date.
- An item number column as soon as your items carry an `item-id`, and a separate unit column.
- A header filled in the brand color that repeats on every page, and stripes in a light tint of it.
- A subtotal under every group, so each delivery note can be checked on its own.
- Boxed totals with the amount to pay on a filled row, and a compact bank block with a 22 mm EPC-QR code.
- A slim continuation header on following pages, and page numbers on invoices with more than one page.

## Make It Yours

Pass your brand color and logo. If 8.5 pt is too small for your readers, raise the body size a little:

```typst
#show: invoice.with(
  theme: theme.compact.with({
    import theme.custom: *
    brand(
      color: rgb("#14532d"), // table header, stripes and totals
      logo: image("logo.svg", alt: "Atelier Nord GmbH"),
    )
    sizes(body: 9pt) // a little larger than the default 8.5 pt
  }),
  // sender: .., recipient: .., invoice-nr: ..
)
```

The default is a steel navy (`#1d3557`). A dark color works best: the table header and the total row carry text in black or white, whichever contrasts more.

## Good to Know

- **Item numbers:** `item-id: (seller: "..")` is the seller's article number. It also goes into the ZUGFeRD XML. See [The `item-id` Parameter](../api-reference/line-items/index.md#the-item-id-parameter-and-zugferd).
- **Columns:** which columns show is decided by [`line-items(show-column: ..)`](../api-reference/line-items/index.md#show-column-dictionary), the order of the value columns by [`theme.custom.items-table(column-order: ..)`](../api-reference/theme/customization.md#options).
- **Printing for a window envelope:** pass a window layout, for example `theme.compact.with(layout: theme.layout.din-5008-a)`. The head then no longer fits one row, but the dense table stays.
