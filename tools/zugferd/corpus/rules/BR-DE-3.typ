// expect: AGREE_INVALID BR-DE-3
// profiles: xrechnung
//
// An XRechnung whose seller address has no city (BT-37).

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: fixture-profile("xrechnung"),
  sender: seller-de + (city: (post-code: "10115")),
  recipient: buyer-de,
  invoice-nr: "BR-DE-3",
)

#line-items[
  #item-s
]
#payment-goal(days: 14)
#bank
