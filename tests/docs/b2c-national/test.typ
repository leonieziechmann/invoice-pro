// Source: docs/docs/b2c.md — "1. Standard National B2C Invoice (Gross Pricing)"
#import "/src/lib.typ": *

#show: invoice.with(
  locale: locale.de-de,
  // B2C requires final gross pricing:
  tax-mode: "inclusive",
  tax: tax.vat(19%), // Applied VAT rate (19% German VAT)

  sender: (
    name: "Web Services & Gear",
    address: "Online Boulevard 8",
    city: "10115 Berlin",
    country: country.de,
    tax-nr: "123/456/78901",
    vat-id: "DE123456789",
  ),

  recipient: (
    name: "Erika Mustermann",
    address: "Rosenweg 12",
    city: "54321 Kundenstadt",
    country: country.de, // Private individual, no tax-nr or vat-id required
  ),

  invoice-nr: "INV-2026-90412",
  date: datetime(year: 2026, month: 7, day: 9),
  subject: [Ihre Bestellung bei Web Services & Gear],
)

= Vielen Dank für Ihre Bestellung!

#line-items[
  #item(
    [Premium Ergonomische Maus],
    quantity: 1,
    unit: unit.piece,
    price: 89.90,
  )
  #item(
    [Mechanische Tastatur (RGB)],
    quantity: 1,
    unit: unit.piece,
    price: 149.00,
  )
  #item([Versicherter Versand], quantity: 1, unit: unit.piece, price: 5.90)
]

#payment-terms(days: 7)

#bank-details(
  bank: "Berliner Volksbank",
  iban: "DE45100900001234567890",
  bic: "BEVODEBBXXX",
)
