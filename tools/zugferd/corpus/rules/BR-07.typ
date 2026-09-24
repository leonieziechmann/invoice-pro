// expect: AGREE_INVALID BR-07
//
// A buyer without a name (BT-44).

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: "en16931",
  sender: seller-de,
  recipient: buyer-fr + (name: none),
  invoice-nr: "BR-07",
)

#line-items[
  #item-s
]
#payment-goal(days: 14)
#bank
