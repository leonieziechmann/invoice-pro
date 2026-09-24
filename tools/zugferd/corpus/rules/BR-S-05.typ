// expect: AGREE_INVALID BR-S-05
//
// Standard rated items (S) at a rate of 0 %, which the category does not allow
// (BT-152).

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: "en16931",
  sender: seller-de,
  recipient: buyer-fr,
  invoice-nr: "BR-S-05",
)

#line-items[
  #item-with(tax.vat(0%))
]
#payment-goal(days: 14)
#bank
