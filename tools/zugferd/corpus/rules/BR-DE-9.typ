// expect: AGREE_INVALID BR-DE-9
//
// An XRechnung whose buyer address has no post code (BT-53).

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: "xrechnung",
  sender: seller-de,
  recipient: buyer-de + (city: "Köln"),
  invoice-nr: "BR-DE-9",
)

#line-items[
  #item-s
]
#payment-goal(days: 14)
#bank
