// An EN 16931 invoice paid by credit card when it was issued: the payment
// means is the card (BT-81 = 54) with its last digits (BT-87) and holder
// (BT-88), the paid amount (BT-113) is the total and nothing is due
// (BT-115). Validated by validate-all-zugferd.

#import "/src/lib.typ": *

#show: invoice.with(
  theme: themes.blank,
  locale: locale.en-de,
  zugferd: "en16931",
  sender: (
    name: "Seller GmbH",
    address: "Street 1",
    city: (name: "München", post-code: "80339"),
    country: country.de,
    tax-nr: "123/456/78901",
    vat-id: "DE123456789",
  ),
  recipient: (
    name: "Acheteur SARL",
    address: "12 rue de la Paix",
    city: (name: "Paris", post-code: "75002"),
    country: country.fr,
    vat-id: "FR40303265045",
  ),
  invoice-nr: "2026-CARD-01",
  date: datetime(year: 2026, month: 9, day: 1),
)

#line-items[
  #item([Conference ticket], price: 490, quantity: 2, tax: tax.vat(19%))
]
#paid(method: "card", date: datetime(year: 2026, month: 9, day: 1))
#card-payment(last4: "4242", holder: "Claire Martin", kind: "credit")
