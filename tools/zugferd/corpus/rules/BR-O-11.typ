// expect: AGREE_INVALID BR-O-11
//
// Items not subject to VAT (O) next to standard rated items on one invoice.

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: "en16931",
  sender: seller-de + (vat-id: none),
  recipient: buyer-fr,
  invoice-nr: "BR-O-11",
)

#line-items[
  #item-s
  #item-with(tax.outside-scope())
]
#payment-goal(days: 14)
#bank
