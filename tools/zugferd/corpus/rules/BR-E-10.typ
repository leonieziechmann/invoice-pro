// expect: AGREE_INVALID BR-E-10
// profiles: basic-wl basic en16931 xrechnung
//
// Exempt items (E) without an exemption reason (BT-120).

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: fixture-profile("en16931"),
  sender: seller-de,
  recipient: buyer-fr,
  invoice-nr: "BR-E-10",
)

#line-items[
  #item-with(tax.exempt())
]
#payment-goal(days: 14)
#bank
