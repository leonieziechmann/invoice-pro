// expect: AGREE_INVALID CII-SR-450
//
// A buyer with both an identifier and a global identifier (BT-46).

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: "en16931",
  sender: seller-de,
  recipient: buyer-fr + (id: "K-4711", global-id: id.gln("4000001987658")),
  invoice-nr: "CII-SR-450",
)

#line-items[
  #item-s
]
#payment-goal(days: 14)
#bank
