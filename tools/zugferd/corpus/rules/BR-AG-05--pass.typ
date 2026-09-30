// expect: AGREE_VALID
// profiles: en16931
//
// IPSI items (M) at a rate above 0 % and at 0 %, which the CEN Schematron
// 1.3.16 and Factur-X 1.09 allow (CEN 1.3.12 in Mustang 2.14.0 did not).

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: fixture-profile("en16931"),
  sender: seller-de,
  recipient: buyer-fr,
  invoice-nr: "BR-AG-05--pass",
)

#line-items[
  #item-with(tax.special.ceuta-melilla(4%))
  #item-with(tax.special.ceuta-melilla(0%))
]
#payment-goal(days: 14)
#bank
