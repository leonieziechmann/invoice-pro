// expect: AGREE_INVALID BR-DE-7
//
// An XRechnung whose seller contact has no email address (BT-43).

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: "xrechnung",
  sender: seller-de + (contact: (name: "Max Muster", phone: "+49 30 1234567")),
  recipient: buyer-de,
  invoice-nr: "BR-DE-7",
)

#line-items[
  #item-s
]
#payment-goal(days: 14)
#bank
