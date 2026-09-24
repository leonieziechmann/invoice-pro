// expect: AGREE_INVALID BR-Z-09
//
// Zero rated items (Z) with a rate other than 0 %, which the category does not
// allow: in BASIC WL, without lines, its VAT breakdown states a VAT amount
// (BT-117) other than 0.

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: "basic-wl",
  sender: seller-de,
  recipient: buyer-fr,
  invoice-nr: "BR-Z-09",
)

#line-items[
  #item-with(tax.new(rate: 7%, category: "Z"))
]
#payment-goal(days: 14)
#bank
