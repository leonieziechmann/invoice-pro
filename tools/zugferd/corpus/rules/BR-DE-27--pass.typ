// expect: AGREE_VALID
// profiles: xrechnung
//
// Three digits are enough.

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: fixture-profile("xrechnung"),
  sender: seller-de + (contact: contact + (phone: "030")),
  recipient: buyer-de,
  invoice-nr: "BR-DE-27--pass",
)

#line-items[
  #item-s
]
#payment-goal(days: 14)
#bank
