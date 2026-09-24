// expect: AGREE_INVALID BR-O-11
// profiles: basic en16931 xrechnung
//
// Items not subject to VAT (O) next to standard rated items: the validators
// report the other VAT breakdown (BR-O-11) and the other line (BR-O-12);
// invoice-pro reports BR-O-11.

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: fixture-profile("en16931"),
  sender: seller-de + (vat-id: none),
  recipient: buyer-fr,
  invoice-nr: "BR-O-12",
)

#line-items[
  #item-s
  #item-with(tax.outside-scope())
]
#payment-goal(days: 14)
#bank
