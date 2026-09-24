// expect: AGREE_INVALID BR-DE-27
//
// An XRechnung whose seller contact phone number (BT-42) has fewer than three
// digits; KoSIT only warns (maintainer decision: an error).

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: "xrechnung",
  sender: seller-de + (contact: contact + (phone: "n. a.")),
  recipient: buyer-de,
  invoice-nr: "BR-DE-27",
)

#line-items[
  #item-s
]
#payment-goal(days: 14)
#bank
