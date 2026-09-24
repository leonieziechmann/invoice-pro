// expect: AGREE_INVALID BR-IC-04
// profiles: basic-wl
//
// An intra-community supply (K) on a document level charge without the buyer
// VAT identifier (BT-48). BASIC WL has no lines, so the rule of the allowance
// or charge applies.

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: fixture-profile("basic-wl"),
  sender: seller-de,
  recipient: buyer-at + (vat-id: none),
  invoice-nr: "BR-IC-04",
)

#line-items[
  #item-with(tax.intra-community())
  #shipping
]
#payment-goal(days: 14)
#bank
