// expect: AGREE_INVALID BR-AG-05
//
// IPSI items (M) at a rate of 0 % (BT-152), which the CEN Schematron 1.3.12 in
// Mustang does not allow; KoSIT's CEN 1.3.16 accepts it (see
// tools/zugferd/validator-differences.toml).

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: "en16931",
  sender: seller-de,
  recipient: buyer-fr,
  invoice-nr: "BR-AG-05",
)

#line-items[
  #item-with(tax.special.ceuta-melilla(0%))
]
#payment-goal(days: 14)
#bank
