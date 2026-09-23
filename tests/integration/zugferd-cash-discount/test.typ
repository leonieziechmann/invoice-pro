// An XRechnung with two cash discounts, stated once in `payment-goal`: the
// invoice prints them, and the payment terms (BT-20) carry them in the Skonto
// syntax of the KoSIT (BR-DE-18), one with a base amount. The account holder
// given to `bank-details` is the account name (BT-85). Validated by
// validate-all-zugferd.

#import "/src/lib.typ": *

#show: invoice.with(
  theme: themes.blank,
  locale: locale.de-de,
  zugferd: "xrechnung",
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
  invoice-nr: "2026-SK-01",
  date: datetime(year: 2026, month: 9, day: 1),
)

#line-items[
  #item([Büromaterial], price: 400, quantity: 1)
  #item([Druckerpatronen], price: 600, quantity: 1)
]
#payment-goal(
  days: 30,
  discount: (
    (days: 7, percent: 3%, basis: 400),
    (days: 14, percent: 2%),
  ),
)
#bank-details(
  name: "Seller Factoring GmbH",
  bank: "Musterbank",
  iban: "DE89370400440532013000",
  bic: "COBADEFFXXX",
)
