// expect: AGREE_INVALID BR-AE-03
// profiles: basic en16931 xrechnung
//
// A document level allowance (BG-20) of a reverse charge (AE) without the
// buyer VAT identifier (BT-48) or its legal registration identifier (BT-47),
// next to standard rated lines (S): the category occurs on the allowance only,
// so the rule of the allowance applies in the profiles with lines as well.

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: fixture-profile("en16931"),
  sender: seller-de,
  recipient: buyer-at + (vat-id: none),
  invoice-nr: "BR-AE-03--allowance-only",
)

#line-items[
  #item-s
  #rebate-with(tax.reverse-charge())
]
#payment-goal(days: 14)
#bank
