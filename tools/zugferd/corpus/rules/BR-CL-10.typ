// expect: AGREE_INVALID BR-CL-10
// profiles: basic en16931 xrechnung
//
// A buyer identifier (BT-46) with a scheme that is no ISO/IEC 6523 code.

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: fixture-profile("en16931"),
  sender: seller-de,
  recipient: buyer-fr + (global-id: (scheme: "9999", id: "4711")),
  invoice-nr: "BR-CL-10",
)

#line-items[
  #item-s
]
#payment-goal(days: 14)
#bank
