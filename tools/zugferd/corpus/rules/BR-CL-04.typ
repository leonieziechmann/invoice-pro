// expect: AGREE_INVALID BR-CL-04
// profiles: basic en16931 xrechnung
//
// An invoice currency (BT-5) that is no ISO 4217 code.

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: fixture-profile("en16931"),
  currency: "ABC",
  sender: seller-de,
  recipient: buyer-fr,
  invoice-nr: "BR-CL-04",
)

#line-items[
  #item-s
]
#payment-goal(days: 14)
#bank
