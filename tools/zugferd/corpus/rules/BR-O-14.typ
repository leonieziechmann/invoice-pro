// expect: AGREE_INVALID BR-O-11
//
// BASIC WL: items not subject to VAT (O) next to standard rated items, and a
// document level charge, split over both categories: the validators report the
// other VAT breakdown (BR-O-11) and the charge of the other category
// (BR-O-14); invoice-pro reports BR-O-11.

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: "basic-wl",
  sender: seller-de + (vat-id: none),
  recipient: buyer-fr,
  invoice-nr: "BR-O-14",
)

#line-items[
  #item-s
  #item-with(tax.outside-scope())
  #shipping
]
#payment-goal(days: 14)
#bank
