// expect: AGREE_INVALID BR-Z-04
// profiles: basic en16931 xrechnung
//
// A document level charge (BG-21) of zero rated items (Z) without the seller
// VAT identifier (BT-31) or tax number (BT-32), next to lines not subject to
// VAT (O), which need no identifier: the category occurs on the charge only,
// so the rule of the charge applies in the profiles with lines as well. A
// category next to O breaks BR-O-11 to BR-O-14 as well (invoice-pro reports
// BR-O-11).

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: fixture-profile("en16931"),
  sender: seller-de-id,
  recipient: buyer-fr,
  invoice-nr: "BR-Z-04--charge-only",
)

#line-items[
  #item-with(tax.outside-scope())
  #shipping-with(tax.zero())
]
#payment-goal(days: 14)
#bank
