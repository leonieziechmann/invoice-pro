// Source: README.md and .github/README.md — "Quick Start"
#import "/src/lib.typ": *

#show: invoice.with(
  locale: locale.en-de,
  sender: (
    name: "Atelier Nord GmbH",
    address: "Hafenstraße 12",
    city: "20457 Hamburg",
    vat-id: "DE123456789",
  ),
  recipient: (
    name: "Acme Corporation",
    address: "Market Street 5",
    city: "80331 Munich",
  ),
  invoice-nr: "2026-0142",
)

#line-items[
  #item([Brand strategy], price: 2400)
  #item([Web design], quantity: 3, unit: unit.day, price: 900)
  #discount([Loyal customer], amount: 5%)
]

#payment-terms(days: 14)
#bank-details(
  bank: "Hamburger Sparkasse",
  iban: "DE75512108001245126199",
  bic: "SOLADEST600",
)
