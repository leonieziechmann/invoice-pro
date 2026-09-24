// expect: AGREE_INVALID BR-CO-26
//
// MINIMUM identifies the seller by its VAT identifier (BT-31) or its legal
// registration identifier (BT-30) only; a tax number does not do.

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: "minimum",
  sender: seller-de + (vat-id: none),
  recipient: buyer-fr,
  invoice-nr: "BR-CO-26--minimum",
)

#line-items[
  #item-s
]
#payment-goal(days: 14)
#bank
