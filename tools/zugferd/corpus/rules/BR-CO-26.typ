// expect: AGREE_INVALID BR-CO-26
// profiles: basic-wl basic en16931 xrechnung
//
// A seller that cannot be identified: no seller identifier (BT-29), legal
// registration identifier (BT-30) or VAT identifier (BT-31).

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: fixture-profile("en16931"),
  sender: seller-de + (vat-id: none, tax-nr: none),
  recipient: buyer-fr,
  invoice-nr: "BR-CO-26",
)

#line-items[
  #item-s
]
#payment-goal(days: 14)
#bank
