// Factur-X BASIC profile: the guideline ID must be the EN 16931 CIUS URN, and
// the seller contact (BG-6) and payment service provider BIC (BT-86) must be
// omitted, since the BASIC XSD rejects them. Both are set here on purpose.
// Validated by validate-all-zugferd.

#import "/src/lib.typ": *

#show: invoice.with(
  theme: themes.blank,
  locale: locale.de-de,
  zugferd: "basic",
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
  invoice-nr: "2026-03",
  order-nr: "PO-2026-9988",
  contract-nr: "CTR-2026-001",
  delivery-note-nr: "DEL-2026-55",
)

#line-items[
  #item([Consulting], price: 100, quantity: 10, unit: "hrs", tax: tax.vat(19%))
  #item([Handbook], price: 24.90, quantity: 2, tax: tax.vat(7%))

  #discount([Loyalty discount], amount: 5%)
  #surcharge([Express surcharge], amount: 25.00)
]
#payment-goal(days: 14)
#bank-details(
  bank: "Musterbank",
  iban: "DE75512108001245126199",
  bic: "SOLADEST600",
)
