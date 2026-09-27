// expect: AGREE_INVALID BR-CL-18
// profiles: basic en16931 xrechnung
//
// A VAT category (BT-151) EN 16931 does not know (AA).

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: fixture-profile("en16931"),
  sender: seller-de,
  recipient: buyer-fr,
  invoice-nr: "BR-CL-18",
)

#line-items[
  #item-with(tax.new(rate: 7%, category: "AA"))
]
#payment-goal(days: 14)
#bank
