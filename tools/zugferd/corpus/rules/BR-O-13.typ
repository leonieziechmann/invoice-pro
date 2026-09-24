// expect: AGREE_INVALID BR-O-11
// profiles: basic-wl basic en16931 xrechnung
//
// BASIC WL: items not subject to VAT (O) next to standard rated items, and a
// document level allowance, split over both categories: the validators report
// the other VAT breakdown (BR-O-11) and the allowance of the other category
// (BR-O-13); invoice-pro reports BR-O-11.

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: fixture-profile("basic-wl"),
  sender: seller-de + (vat-id: none),
  recipient: buyer-fr,
  invoice-nr: "BR-O-13",
)

#line-items[
  #item-s
  #item-with(tax.outside-scope())
  #rebate
]
#payment-goal(days: 14)
#bank
