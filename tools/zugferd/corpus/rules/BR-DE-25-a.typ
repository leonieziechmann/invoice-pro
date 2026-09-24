// expect: AGREE_INVALID BR-DE-25-a
//
// An XRechnung paid by SEPA direct debit without the direct debit (BG-19).

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: "xrechnung",
  sender: seller-de,
  recipient: buyer-de,
  invoice-nr: "BR-DE-25-a",
)

#line-items[
  #item-s
]
#paid(method: "direct-debit")
