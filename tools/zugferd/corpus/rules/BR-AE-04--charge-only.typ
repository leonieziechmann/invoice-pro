// expect: AGREE_INVALID BR-AE-04
// profiles: basic en16931 xrechnung
//
// A document level charge (BG-21) of a reverse charge (AE) without the buyer
// VAT identifier (BT-48) or its legal registration identifier (BT-47), next to
// standard rated lines (S): the category occurs on the charge only, so the
// rule of the charge applies in the profiles with lines as well.

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: fixture-profile("en16931"),
  sender: seller-de,
  recipient: buyer-at + (vat-id: none),
  invoice-nr: "BR-AE-04--charge-only",
)

#line-items[
  #item-s
  #shipping-with(tax.reverse-charge())
]
#payment-goal(days: 14)
#bank
