// expect: AGREE_INVALID BR-S-06
//
// Standard rated items (S) at a rate of 0 %, which the category does not allow
// (BT-96), on a document level allowance. BASIC WL has no lines, so the rule
// of the allowance or charge applies.

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: "basic-wl",
  sender: seller-de,
  recipient: buyer-fr,
  invoice-nr: "BR-S-06",
)

#line-items[
  #item-with(tax.vat(0%))
  #rebate
]
#payment-goal(days: 14)
#bank
