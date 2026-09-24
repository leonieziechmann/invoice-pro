// expect: AGREE_INVALID BR-DE-8
// profiles: xrechnung
//
// An XRechnung whose buyer address has no city (BT-52).

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: fixture-profile("xrechnung"),
  sender: seller-de,
  recipient: buyer-de + (city: (post-code: "50667")),
  invoice-nr: "BR-DE-8",
)

#line-items[
  #item-s
]
#payment-goal(days: 14)
#bank
