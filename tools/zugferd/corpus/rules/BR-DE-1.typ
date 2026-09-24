// expect: AGREE_INVALID BR-DE-1
//
// An XRechnung without payment instructions (BG-16).

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: "xrechnung",
  sender: seller-de,
  recipient: buyer-de,
  invoice-nr: "BR-DE-1",
)

#line-items[
  #item-s
]
#payment-goal(days: 14)
