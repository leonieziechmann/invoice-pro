// Source: docs/docs/themes/boxed.md — "Quick Start"
#import "/src/lib.typ": *

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
