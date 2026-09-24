// expect: AGREE_VALID
// profiles: en16931
//
// An intra-community supply to a buyer with its VAT identifier.

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: fixture-profile("en16931"),
  sender: seller-de,
  recipient: buyer-at,
  invoice-nr: "BR-IC-02--pass",
)

#line-items[
  #item-with(tax.intra-community())
]
#payment-goal(days: 14)
#bank
