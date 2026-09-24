// expect: AGREE_INVALID BR-Z-07
//
// Zero rated items (Z) with a rate other than 0 %, which the category does not
// allow (BT-103), on a document level charge. BASIC WL has no lines, so the
// rule of the allowance or charge applies.

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: "basic-wl",
  sender: seller-de,
  recipient: buyer-fr,
  invoice-nr: "BR-Z-07",
)

#line-items[
  #item-with(tax.new(rate: 7%, category: "Z"))
  #shipping
]
#payment-goal(days: 14)
#bank
