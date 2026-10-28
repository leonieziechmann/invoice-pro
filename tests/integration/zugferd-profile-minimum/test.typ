// Factur-X MINIMUM profile: only header data and the document totals. The
// seller postal address is reduced to the country code (BR-08, BR-09), and the
// seller is identified by its VAT ID (BR-CO-26). Everything MINIMUM does not
// know is set on purpose and must be omitted: electronic addresses, seller
// contact, buyer VAT ID and address, payment means, VAT breakdown, allowances
// and charges, payment terms and the contract and delivery note references.
// The amount due still accounts for the prepayment. The order number (BT-13)
// is kept. Validated by validate-all-zugferd.

#import "/src/lib.typ": *

#show: invoice.with(
  theme: theme.plain,
  locale: locale.de-de,
  zugferd: "minimum",
  // incomplete e-invoice data must fail the build, not withhold the XML
  validation: "strict",
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
    vat-id: "DE987654321",
    email: "accounting@buyer.de",
    buyer-reference: "DE123456789-12345-12",
  ),
  invoice-nr: "2026-04",
  order-nr: "PO-2026-9988",
  contract-nr: "CTR-2026-001",
  delivery-note-nr: "DEL-2026-55",
)

#line-items[
  #item([Consulting], price: 100, quantity: 10, unit: "hrs", tax: tax.vat(19%))
  #item([Handbook], price: 24.90, quantity: 2, tax: tax.vat(7%))

  #discount([Loyalty discount], amount: 5%)
  #surcharge([Express surcharge], amount: 25.00)

  #prepayment(300)
]
#payment-terms(days: 14)
#bank-details(
  bank: "Musterbank",
  iban: "DE75512108001245126199",
  bic: "SOLADEST600",
)
