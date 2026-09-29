// Source: docs/docs/themes/prestige.md — "Quick Start"
#import "/src/lib.typ": *

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
