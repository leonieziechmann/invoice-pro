// expect: AGREE_INVALID BR-CL-11
//
// A seller legal registration identifier (BT-30) with a scheme that is no
// ISO/IEC 6523 code.

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: "en16931",
  sender: seller-de + (legal-id: id.custom("9999", "4711")),
  recipient: buyer-fr,
  invoice-nr: "BR-CL-11",
)

#line-items[
  #item-s
]
#payment-goal(days: 14)
#bank
