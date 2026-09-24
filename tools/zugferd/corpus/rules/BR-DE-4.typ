// expect: AGREE_INVALID BR-DE-4
// profiles: xrechnung
//
// An XRechnung whose seller address has no post code (BT-38).

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: fixture-profile("xrechnung"),
  sender: seller-de + (city: "Berlin"),
  recipient: buyer-de,
  invoice-nr: "BR-DE-4",
)

#line-items[
  #item-s
]
#payment-goal(days: 14)
#bank
