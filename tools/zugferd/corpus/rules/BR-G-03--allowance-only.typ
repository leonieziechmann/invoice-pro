// expect: AGREE_INVALID BR-G-03
// profiles: basic en16931 xrechnung
//
// A document level allowance (BG-20) of an export outside the EU (G) without
// the seller VAT identifier (BT-31), which its tax number does not replace,
// next to lines not subject to VAT (O), which need no identifier: the category
// occurs on the allowance only, so the rule of the allowance applies in the
// profiles with lines as well. A category next to O breaks BR-O-11 to BR-O-14
// as well (invoice-pro reports BR-O-11).

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: fixture-profile("en16931"),
  sender: seller-de + (vat-id: none),
  recipient: buyer-us,
  invoice-nr: "BR-G-03--allowance-only",
)

#line-items[
  #item-with(tax.outside-scope())
  #rebate-with(tax.export())
]
#payment-goal(days: 14)
#bank
