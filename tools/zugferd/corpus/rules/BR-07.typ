// expect: AGREE_INVALID BR-07
// profiles: minimum basic-wl basic en16931 xrechnung
//
// A buyer without a name (BT-44).

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: fixture-profile("en16931"),
  sender: seller-de,
  recipient: buyer-fr + (name: none),
  invoice-nr: "BR-07",
)

#line-items[
  #item-s
]
#payment-goal(days: 14)
#bank
