#import "/src/lib.typ": *

#show: invoice.with(
  theme: themes.DIN-5008(font: "libertinus serif"),
  locale: locale.de-de,
  zugferd: "en16931",
  sender: (
    name: "Supplier GmbH",
    address: "Str 1",
    city: "20095 Hamburg",
    country: country.de,
    tax-nr: "123/456/78901",
    vat-id: "DE123456789",
    contact: (
      name: "Anna Schmidt",
      phone: "+49 40 123456",
      email: "anna@supplier.de",
    ),
  ),
  recipient: (
    name: "HQ Corp AG",
    address: "HQ 1",
    city: "60311 Frankfurt",
    country: country.de,
    vat-id: "DE987654321",
    buyer-reference: "04011000-12345-67",
  ),
  delivery-address: (
    name: "Warehouse Leipzig",
    address: "Tor 4",
    city: "04109 Leipzig",
    country: country.de,
  ),
  date: datetime(year: 2026, month: 9, day: 3),
  invoice-nr: "INV-2026-DELIV",
  references: (
    references.invoice-nr(),
    references.delivery-address(),
  ),
)

#line-items[
  #item([Hardware Server Rack], price: 2500.00, quantity: 1)
]

#payment-goal(days: 30)

#bank-details(
  bank: "Musterbank",
  iban: "DE07100202005821158846",
  bic: "BHBLDEHHXXX",
)
