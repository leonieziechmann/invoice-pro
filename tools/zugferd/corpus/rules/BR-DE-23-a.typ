// expect: AGREE_INVALID BR-DE-23-a
//
// An XRechnung paid by credit transfer without the account (BG-17).

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: "xrechnung",
  sender: seller-de,
  recipient: buyer-de,
  invoice-nr: "BR-DE-23-a",
)

#line-items[
  #item-s
]
#paid(method: "transfer")
