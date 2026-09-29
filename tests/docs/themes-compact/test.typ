// Source: docs/docs/themes/compact.md — "Quick Start"
#import "/src/lib.typ": *

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
