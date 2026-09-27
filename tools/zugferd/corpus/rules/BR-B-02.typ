// expect: AGREE_INVALID BR-B-02
// profiles: basic en16931 xrechnung
//
// A domestic Italian invoice with the split payment of Italy (B) next to a
// standard rated item (S).

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: fixture-profile("xrechnung"),
  sender: seller-it,
  recipient: buyer-it,
  invoice-nr: "BR-B-02",
)

#line-items[
  #item-with(tax.special.transferred(22%))
  #item-with(tax.vat(22%))
]
#payment-goal(days: 14)
#bank
