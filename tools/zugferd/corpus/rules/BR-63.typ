// expect: AGREE_INVALID BR-63
// profiles: basic-wl basic en16931 xrechnung
//
// A buyer electronic address (BT-49) without its scheme identifier.

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: fixture-profile("en16931"),
  sender: seller-de,
  recipient: buyer-fr + (electronic-address: "4000001123452"),
  invoice-nr: "BR-63",
)

#line-items[
  #item-s
]
#payment-goal(days: 14)
#bank
