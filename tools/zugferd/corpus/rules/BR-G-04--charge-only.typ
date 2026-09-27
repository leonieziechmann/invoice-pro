// expect: AGREE_INVALID BR-G-04
// profiles: basic en16931 xrechnung
//
// A document level charge (BG-21) of an export outside the EU (G) without the
// seller VAT identifier (BT-31), which its tax number does not replace, next
// to lines not subject to VAT (O), which need no identifier: the category
// occurs on the charge only, so the rule of the charge applies in the profiles
// with lines as well. A category next to O breaks BR-O-11 to BR-O-14 as well
// (invoice-pro reports BR-O-11).

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: fixture-profile("en16931"),
  sender: seller-de + (vat-id: none),
  recipient: buyer-us,
  invoice-nr: "BR-G-04--charge-only",
)

#line-items[
  #item-with(tax.outside-scope())
  #shipping-with(tax.export())
]
#payment-goal(days: 14)
#bank
