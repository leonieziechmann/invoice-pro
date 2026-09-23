// Source: docs/docs/b2c.md — "2. Small Business Exemption B2C Invoice"
// Compile-only: the example must compile as documented (it used to
// carry an invalid IBAN).
#import "/src/lib.typ": *

#show: invoice.with(
  locale: locale.de-de,
  tax-mode: "inclusive",
  // Enable small business exemption:
  tax-exempt-small-biz: true,
  tax: auto, // Required to be auto when tax-exempt-small-biz is true

  sender: (
    name: "Fotografie & Design Schmidt",
    address: "Kreativstraße 3",
    city: "50667 Köln",
    country: country.de,
    tax-nr: "215/987/65432", // Supplier tax number is required
  ),

  recipient: (
    name: "Thomas Müller",
    address: "Rheinufer 99",
    city: "50996 Köln",
    country: country.de,
  ),

  invoice-nr: "INV-SCHMIDT-1002",
  date: datetime(year: 2026, month: 7, day: 9),
  subject: [Rechnung - Fotoshooting Thomas Müller],
)

= Fotoshootings & Bildbearbeitung

#line-items[
  #item(
    [Portrait-Fotoshooting (2 Std.)],
    quantity: 1,
    unit: unit.piece,
    price: 180.00,
  )
  #item(
    [Bildnachbearbeitung (Premium)],
    quantity: 5,
    unit: unit.piece,
    price: 15.00,
  )
]

#payment-goal(days: 14)

#bank-details(
  bank: "Commerzbank",
  iban: "DE89370400440532013000",
  bic: "COBADEFFXXX",
)
