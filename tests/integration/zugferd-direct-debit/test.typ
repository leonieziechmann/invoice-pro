// An XRechnung collected by SEPA direct debit (BT-81 = 59): the mandate
// reference (BT-89), the creditor identifier (BT-90) and the debited account
// (BT-91). Validated by validate-all-zugferd.

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
  invoice-nr: "2026-DD-01",
  date: datetime(year: 2026, month: 9, day: 1),
)

#line-items[
  #item([Wartungsvertrag September], price: 250, quantity: 1)
]
#payment-goal(days: 14)
#direct-debit(
  mandate: "M-2026-017",
  creditor-id: "DE98 ZZZ 0999 9999 999",
  debtor-iban: "DE02 1203 0000 0000 2020 51",
)
