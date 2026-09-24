// expect: AGREE_INVALID BR-AG-04
//
// IPSI items (M) on a document level charge without the seller VAT identifier
// (BT-31) or tax number (BT-32). BASIC WL has no lines, so the rule of the
// allowance or charge applies.

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: "basic-wl",
  sender: seller-de-id,
  recipient: buyer-fr,
  invoice-nr: "BR-AG-04",
)

#line-items[
  #item-with(tax.special.ceuta-melilla(4%))
  #shipping
]
#payment-goal(days: 14)
#bank
