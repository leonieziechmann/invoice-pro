// expect: AGREE_INVALID BR-AG-07
// profiles: basic-wl
//
// IPSI items (M) at a rate of 0 %, which the category does not allow (BT-103),
// on a document level charge. BASIC WL has no lines, so the rule of the
// allowance or charge applies.

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: fixture-profile("basic-wl"),
  sender: seller-de,
  recipient: buyer-fr,
  invoice-nr: "BR-AG-07",
)

#line-items[
  #item-with(tax.special.ceuta-melilla(0%))
  #shipping
]
#payment-goal(days: 14)
#bank
