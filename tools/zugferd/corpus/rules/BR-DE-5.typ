// expect: AGREE_INVALID BR-DE-5
// profiles: xrechnung
//
// An XRechnung whose seller contact has no name (BT-41).

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: fixture-profile("xrechnung"),
  sender: seller-de
    + (contact: (phone: "+49 30 1234567", email: "rechnung@muster.example")),
  recipient: buyer-de,
  invoice-nr: "BR-DE-5",
)

#line-items[
  #item-s
]
#payment-goal(days: 14)
#bank
