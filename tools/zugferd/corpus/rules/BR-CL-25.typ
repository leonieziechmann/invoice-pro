// expect: AGREE_INVALID BR-CL-25
// profiles: basic en16931 xrechnung
//
// A buyer electronic address (BT-49) with a scheme outside the EAS code list.

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: fixture-profile("en16931"),
  sender: seller-de,
  recipient: buyer-fr + (electronic-address: (scheme: "9999", id: "4711")),
  invoice-nr: "BR-CL-25",
)

#line-items[
  #item-s
]
#payment-goal(days: 14)
#bank
