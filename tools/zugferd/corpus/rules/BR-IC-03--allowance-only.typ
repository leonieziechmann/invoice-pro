// expect: AGREE_INVALID BR-IC-03
// profiles: basic en16931 xrechnung
//
// A document level allowance (BG-20) of an intra-community supply (K) without
// the buyer VAT identifier (BT-48), next to standard rated lines (S): the
// category occurs on the allowance only, so the rule of the allowance applies
// in the profiles with lines as well.

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: fixture-profile("en16931"),
  sender: seller-de,
  recipient: buyer-at + (vat-id: none),
  invoice-nr: "BR-IC-03--allowance-only",
)

#line-items[
  #item-s
  #rebate-with(tax.intra-community())
]
#payment-goal(days: 14)
#bank
