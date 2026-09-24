// expect: AGREE_INVALID BR-DE-15
// profiles: xrechnung
//
// An XRechnung without the buyer reference (BT-10).

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: fixture-profile("xrechnung"),
  sender: seller-de,
  recipient: buyer-de + (buyer-reference: none),
  invoice-nr: "BR-DE-15",
)

#line-items[
  #item-s
]
#payment-goal(days: 14)
#bank
