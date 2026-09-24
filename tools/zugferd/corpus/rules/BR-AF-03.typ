// expect: AGREE_INVALID BR-AF-03
//
// IGIC items (L) on a document level allowance without the seller VAT
// identifier (BT-31) or tax number (BT-32). BASIC WL has no lines, so the rule
// of the allowance or charge applies.

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: "basic-wl",
  sender: seller-de-id,
  recipient: buyer-fr,
  invoice-nr: "BR-AF-03",
)

#line-items[
  #item-with(tax.special.canary-islands(7%))
  #rebate
]
#payment-goal(days: 14)
#bank
