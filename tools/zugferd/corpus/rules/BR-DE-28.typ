// expect: AGREE_INVALID BR-DE-28
//
// An XRechnung whose seller contact email address (BT-43) does not match the
// pattern of the XRechnung Schematron; KoSIT only warns.

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: "xrechnung",
  sender: seller-de + (contact: contact + (email: "rechnung@muster")),
  recipient: buyer-de,
  invoice-nr: "BR-DE-28",
)

#line-items[
  #item-s
]
#payment-goal(days: 14)
#bank
