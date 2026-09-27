// expect: AGREE_INVALID BR-AE-03
// profiles: basic-wl
//
// A reverse charge (AE) on a document level allowance without the buyer VAT
// identifier (BT-48) or its legal registration identifier (BT-47). BASIC WL
// has no lines, so the rule of the allowance or charge applies.

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: fixture-profile("basic-wl"),
  sender: seller-de,
  recipient: buyer-at + (vat-id: none),
  invoice-nr: "BR-AE-03",
)

#line-items[
  #item-with(tax.reverse-charge())
  #rebate
]
#payment-goal(days: 14)
#bank
