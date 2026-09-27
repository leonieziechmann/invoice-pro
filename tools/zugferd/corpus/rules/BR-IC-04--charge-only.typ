// expect: AGREE_INVALID BR-IC-04
// profiles: basic en16931 xrechnung
//
// A document level charge (BG-21) of an intra-community supply (K) without the
// buyer VAT identifier (BT-48), next to standard rated lines (S): the category
// occurs on the charge only, so the rule of the charge applies in the profiles
// with lines as well.

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: fixture-profile("en16931"),
  sender: seller-de,
  recipient: buyer-at + (vat-id: none),
  invoice-nr: "BR-IC-04--charge-only",
)

#line-items[
  #item-s
  #shipping-with(tax.intra-community())
]
#payment-goal(days: 14)
#bank
