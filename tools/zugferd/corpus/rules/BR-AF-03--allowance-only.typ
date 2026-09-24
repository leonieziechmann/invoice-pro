// expect: AGREE_INVALID BR-AF-03
// profiles: basic en16931 xrechnung
//
// A document level allowance (BG-20) of IGIC items (L) without the seller VAT
// identifier (BT-31) or tax number (BT-32), next to lines not subject to VAT
// (O), which need no identifier: the category occurs on the allowance only, so
// the rule of the allowance applies in the profiles with lines as well. A
// category next to O breaks BR-O-11 to BR-O-14 as well (invoice-pro reports
// BR-O-11).

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: fixture-profile("en16931"),
  sender: seller-de-id,
  recipient: buyer-fr,
  invoice-nr: "BR-AF-03--allowance-only",
)

#line-items[
  #item-with(tax.outside-scope())
  #rebate-with(tax.special.canary-islands(7%))
]
#payment-goal(days: 14)
#bank
