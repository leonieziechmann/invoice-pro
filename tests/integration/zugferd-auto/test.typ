// `zugferd: auto` between German parties with complete data: the invoice is
// written as XRechnung 3.0. Validated by validate-all-zugferd.

#import "/src/lib.typ": *

#show: invoice.with(
  theme: themes.blank,
  locale: locale.de-de,
  zugferd: auto,
  sender: (
    name: "Seller GmbH",
    address: "Street 1",
    city: (name: "München", post-code: "80339"),
    country: country.de,
    vat-id: "DE123456789",
    contact: (
      name: "Max Mustermann",
      phone: "+49 89 123456",
      email: "seller@example.de",
    ),
  ),
  recipient: (
    name: "Buyer GmbH",
    address: "Weg 5",
    city: (name: "Berlin", post-code: "10115"),
    country: country.de,
    email: "buyer@example.de",
    buyer-reference: "04011000-12345-67",
  ),
  invoice-nr: "2026-01",
  date: datetime(year: 2026, month: 9, day: 1),
)

#line-items[
  #item([Consulting], price: 100, quantity: 8, unit: unit.hour)
]
#payment-goal(days: 14)
#bank-details(
  bank: "Musterbank",
  iban: "DE89370400440532013000",
  bic: "COBADEFFXXX",
)
