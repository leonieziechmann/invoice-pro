// Source: docs/docs/themes/corporate.md — "Quick Start"
#import "/src/lib.typ": *

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
