// expect: AGREE_INVALID BR-06
// profiles: minimum basic-wl basic en16931 xrechnung
//
// A seller without a name (BT-27).

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: fixture-profile("en16931"),
  sender: seller-de + (name: none),
  recipient: buyer-fr,
  invoice-nr: "BR-06",
)

#line-items[
  #item-s
]
#payment-goal(days: 14)
#bank
