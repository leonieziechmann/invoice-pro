// expect: AGREE_INVALID BR-DE-24-a
// profiles: xrechnung
//
// An XRechnung paid by payment card without the card (BG-18).

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: fixture-profile("xrechnung"),
  sender: seller-de,
  recipient: buyer-de,
  invoice-nr: "BR-DE-24-a",
)

#line-items[
  #item-s
]
#paid(method: "card")
