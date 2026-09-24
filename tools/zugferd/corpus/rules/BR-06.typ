// expect: AGREE_INVALID BR-06
//
// A seller without a name (BT-27).

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: "en16931",
  sender: seller-de + (name: none),
  recipient: buyer-fr,
  invoice-nr: "BR-06",
)

#line-items[
  #item-s
]
#payment-goal(days: 14)
#bank
