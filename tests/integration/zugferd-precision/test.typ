// XRechnung with unit prices of more than two decimals (BT-146), fractional
// quantities (BT-129), a price per base quantity (BT-149) and a credited line.
// Prices and quantities keep their decimals, the base quantity is stated, so
// price times quantity matches each line total. A negative price is written as
// a positive price of a negative quantity (BR-27). Validated by
// validate-all-zugferd.

#import "/src/lib.typ": *

#show: invoice.with(
  theme: themes.blank,
  locale: locale.de-de,
  zugferd: "en16931",
  sender: (
    name: "Seller GmbH",
    address: "Street 1",
    city: (name: "München", post-code: "80339"),
    country: country.de,
    tax-nr: "123/456/78901",
    vat-id: "DE123456789",
    contact: (
      name: "Max Mustermann",
      phone: "+49 89 1234567",
      email: "max@seller.de",
    ),
  ),
  recipient: (
    name: "Buyer GmbH",
    address: "Weg 5",
    city: (name: "Berlin", post-code: "10115"),
    country: country.de,
    email: "accounting@buyer.de",
    buyer-reference: "DE123456789-12345-12",
  ),
  invoice-nr: "2026-05",
  date: datetime(year: 2026, month: 9, day: 1),
)

#line-items[
  #item([Screws], price: 0.1234, quantity: 1000, unit: unit.piece)
  #item([Consulting], price: 95.00, quantity: 0.125, unit: unit.hour)
  #item(
    [Copy paper (per 100 sheets)],
    price: 4.99,
    quantity: 250,
    base-quantity: 100,
    unit: unit.piece,
  )
  #item([Fuel], price: 1.789, quantity: 45.37, unit: unit.litre)
  #item([Returned toner], price: -39.90, quantity: 1)
]
#payment-goal(days: 14)
#bank-details(
  bank: "Musterbank",
  iban: "DE75512108001245126199",
  bic: "SOLADEST600",
)
