// expect: AGREE_INVALID BR-Z-06
// profiles: basic-wl
//
// Zero rated items (Z) with a rate other than 0 %, which the category does not
// allow (BT-96), on a document level allowance. BASIC WL has no lines, so the
// rule of the allowance or charge applies.

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: fixture-profile("basic-wl"),
  sender: seller-de,
  recipient: buyer-fr,
  invoice-nr: "BR-Z-06",
)

#line-items[
  #item-with(tax.new(rate: 7%, category: "Z"))
  #rebate
]
#payment-goal(days: 14)
#bank
