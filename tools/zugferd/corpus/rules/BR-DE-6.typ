// expect: AGREE_INVALID BR-DE-6
// profiles: xrechnung
//
// An XRechnung whose seller contact has no phone number (BT-42).

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: fixture-profile("xrechnung"),
  sender: seller-de
    + (contact: (name: "Max Muster", email: "rechnung@muster.example")),
  recipient: buyer-de,
  invoice-nr: "BR-DE-6",
)

#line-items[
  #item-s
]
#payment-goal(days: 14)
#bank
