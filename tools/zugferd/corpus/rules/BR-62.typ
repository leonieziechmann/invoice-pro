// expect: AGREE_INVALID BR-62
// profiles: basic-wl basic en16931 xrechnung
//
// A seller electronic address (BT-34) without its scheme identifier.

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: fixture-profile("en16931"),
  sender: seller-de + (electronic-address: "4000001123452"),
  recipient: buyer-fr,
  invoice-nr: "BR-62",
)

#line-items[
  #item-s
]
#payment-goal(days: 14)
#bank
