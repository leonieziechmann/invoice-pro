// expect: AGREE_INVALID BR-DE-1
// profiles: xrechnung
//
// An XRechnung without payment instructions (BG-16).

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: fixture-profile("xrechnung"),
  sender: seller-de,
  recipient: buyer-de,
  invoice-nr: "BR-DE-1",
)

#line-items[
  #item-s
]
#payment-goal(days: 14)
