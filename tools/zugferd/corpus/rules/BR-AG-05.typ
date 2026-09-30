// expect: AGREE_INVALID BR-AG-05
// profiles: basic en16931 xrechnung
//
// IPSI items (M) at a negative rate (BT-152), which the CEN Schematron 1.3.16
// and Factur-X 1.09 reject; 0 % is allowed (BR-AG-05--pass.typ).

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: fixture-profile("en16931"),
  sender: seller-de,
  recipient: buyer-fr,
  invoice-nr: "BR-AG-05",
)

#line-items[
  #item-with(tax.special.ceuta-melilla(-1%))
]
#payment-goal(days: 14)
#bank
