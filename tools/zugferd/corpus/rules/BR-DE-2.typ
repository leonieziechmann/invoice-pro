// expect: AGREE_INVALID BR-DE-2
// profiles: xrechnung
//
// An XRechnung without the seller contact (BG-6).

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: fixture-profile("xrechnung"),
  sender: seller-de + (contact: none),
  recipient: buyer-de,
  invoice-nr: "BR-DE-2",
)

#line-items[
  #item-s
]
#payment-goal(days: 14)
#bank
