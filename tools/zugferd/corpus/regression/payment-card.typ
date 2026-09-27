// expect: AGREE_VALID
// finding: amounts-payment-means-api-gap
// facts: {"payment_means": ["54"], "card": ["1234", "Erika Kunde"]}
//
// An XRechnung charged to a credit card (BT-81 = 54): the last digits of
// the card number (BT-87) and the card holder (BT-88).

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: "xrechnung",
  sender: seller-de,
  recipient: buyer-de,
  invoice-nr: "RG-KARTE",
)

#line-items[
  #item([Beratung], price: 100, quantity: 10, tax: tax.vat(19%))
]
#payment-goal()
#card-payment(last4: "1234", holder: "Erika Kunde", kind: "credit")
