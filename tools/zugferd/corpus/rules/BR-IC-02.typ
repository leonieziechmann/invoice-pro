// expect: AGREE_INVALID BR-IC-02
//
// An intra-community supply (K) on invoice lines without the buyer VAT
// identifier (BT-48).

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: "en16931",
  sender: seller-de,
  recipient: buyer-at + (vat-id: none),
  invoice-nr: "BR-IC-02",
)

#line-items[
  #item-with(tax.intra-community())
]
#payment-goal(days: 14)
#bank
