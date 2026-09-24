// expect: AGREE_INVALID CII-SR-451
//
// A payee with both an identifier and a global identifier (BT-60).

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: "en16931",
  payee: (
    name: "Factoring Bank AG",
    id: "F-17",
    global-id: id.gln("4000001543212"),
  ),
  sender: seller-de,
  recipient: buyer-fr,
  invoice-nr: "CII-SR-451",
)

#line-items[
  #item-s
]
#payment-goal(days: 14)
#bank
