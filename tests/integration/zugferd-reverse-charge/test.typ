#import "/src/lib.typ": *

#show: invoice.with(
  theme: themes.blank,
  locale: locale.en-de,
  zugferd: "en16931",
  tax: tax.reverse-charge(),
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
    email: "accounting@buyer.fr",
    vat-id: "FR99123456789",
    buyer-reference: "FR123456789",
  ),
  invoice-nr: "2026-RC-01",
)

#line-items[
  #item([Consulting Services], price: 1000.00, quantity: 1)
]
#payment-goal(days: 30)
#bank-details(
  bank: "Musterbank",
  iban: "DE89370400440532013000",
  bic: "BANK123X",
)
