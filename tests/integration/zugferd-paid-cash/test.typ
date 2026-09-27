// An XRechnung paid in cash (BT-81 = 10): the paid amount (BT-113) is the
// total, nothing is due (BT-115), and the payment terms (BT-20) state what
// the invoice prints about the payment. Validated by validate-all-zugferd.

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
  invoice-nr: "2026-BAR-01",
  date: datetime(year: 2026, month: 9, day: 1),
)

#line-items[
  #item([Reparatur vor Ort], price: 80, quantity: 1.5, unit: unit.hour)
  #item([Ersatzteil], price: 35)
]
#paid(method: "cash", date: datetime(year: 2026, month: 9, day: 1))
