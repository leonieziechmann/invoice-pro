// Intra-community supply (VAT category K) to a French business. The exemption
// reason defaults to "Intra-community supply" (BR-IC-10), and without a
// delivery address the goods are delivered to the buyer's country
// (BR-IC-12). Validated by validate-all-zugferd.

#import "/src/lib.typ": *

#show: invoice.with(
  theme: themes.blank,
  locale: locale.en-de,
  zugferd: "en16931",
  tax: tax.intra-community(),
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
    name: "Buyer SAS",
    address: "Rue de Paris 1",
    city: (name: "Paris", post-code: "75001"),
    country: country.fr,
    vat-id: "FR99123456789",
  ),
  invoice-nr: "2026-IC-01",
  date: datetime(year: 2026, month: 9, day: 1),
)

#line-items[
  #item([Machine parts], price: 1250.00, quantity: 4, unit: unit.piece)
  #item([Freight], price: 180.00)
]
#payment-goal(days: 30)
#bank-details(
  bank: "Musterbank",
  iban: "DE75512108001245126199",
  bic: "SOLADEST600",
)
