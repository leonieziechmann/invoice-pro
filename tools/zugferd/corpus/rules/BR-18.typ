// expect: AGREE_INVALID BR-18
//
// A seller tax representative (BG-11) without a name (BT-62).

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: "en16931",
  sender: seller-de + (tax-representative: representative + (name: none)),
  recipient: buyer-fr,
  invoice-nr: "BR-18",
)

#line-items[
  #item-s
]
#payment-goal(days: 14)
#bank
