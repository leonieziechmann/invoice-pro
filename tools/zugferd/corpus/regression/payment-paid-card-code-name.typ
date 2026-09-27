// expect: AGREE_VALID
// finding: amounts-payment-means-api-gap
//
// `paid` with a payment means code of its own (54, credit card) and its
// name next to the details of the card: the code is stated once, with the
// card details (BG-18), and the name in the payment terms (BT-20). Next to
// `card-payment()` (48), the codes would contradict each other, which stops
// the compilation.

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: "xrechnung",
  sender: seller-de,
  recipient: buyer-de,
  invoice-nr: "RG-PAID-VISA",
)

#line-items[
  #item([Wartung], quantity: 2, unit: unit.hour, price: 95)
]
#paid(method: (code: "54", name: [Visa]))
#card-payment(last4: "4242", holder: "Erika Kunde", kind: "credit")
