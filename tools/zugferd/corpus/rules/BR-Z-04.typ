// expect: AGREE_INVALID BR-Z-04
//
// Zero rated items (Z) on a document level charge without the seller VAT
// identifier (BT-31) or tax number (BT-32). BASIC WL has no lines, so the rule
// of the allowance or charge applies.

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: "basic-wl",
  sender: seller-de-id,
  recipient: buyer-fr,
  invoice-nr: "BR-Z-04",
)

#line-items[
  #item-with(tax.zero())
  #shipping
]
#payment-goal(days: 14)
#bank
