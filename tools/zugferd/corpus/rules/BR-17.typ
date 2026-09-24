// expect: AGREE_INVALID BR-17
//
// A payee (BG-10) with the seller's name: a payee is named only when someone
// other than the seller receives the payment.

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: "en16931",
  payee: (name: "Muster GmbH"),
  sender: seller-de,
  recipient: buyer-fr,
  invoice-nr: "BR-17",
)

#line-items[
  #item-s
]
#payment-goal(days: 14)
#bank
