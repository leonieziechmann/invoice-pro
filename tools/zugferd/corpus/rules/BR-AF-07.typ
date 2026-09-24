// expect: AGREE_INVALID BR-AF-07
//
// IGIC items (L) at a rate of 0 %, which the category does not allow (BT-103),
// on a document level charge. BASIC WL has no lines, so the rule of the
// allowance or charge applies.

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: "basic-wl",
  sender: seller-de,
  recipient: buyer-fr,
  invoice-nr: "BR-AF-07",
)

#line-items[
  #item-with(tax.special.canary-islands(0%))
  #shipping
]
#payment-goal(days: 14)
#bank
