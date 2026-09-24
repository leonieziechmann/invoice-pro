// expect: AGREE_VALID
//
// IPSI items (M) at a rate above 0 %.

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: "en16931",
  sender: seller-de,
  recipient: buyer-fr,
  invoice-nr: "BR-AG-05--pass",
)

#line-items[
  #item-with(tax.special.ceuta-melilla(4%))
]
#payment-goal(days: 14)
#bank
