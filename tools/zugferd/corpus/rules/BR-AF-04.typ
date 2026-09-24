// expect: AGREE_INVALID BR-AF-04
// profiles: basic-wl
//
// IGIC items (L) on a document level charge without the seller VAT identifier
// (BT-31) or tax number (BT-32). BASIC WL has no lines, so the rule of the
// allowance or charge applies.

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: fixture-profile("basic-wl"),
  sender: seller-de-id,
  recipient: buyer-fr,
  invoice-nr: "BR-AF-04",
)

#line-items[
  #item-with(tax.special.canary-islands(7%))
  #shipping
]
#payment-goal(days: 14)
#bank
