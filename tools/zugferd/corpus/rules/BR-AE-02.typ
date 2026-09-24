// expect: AGREE_INVALID BR-AE-02
//
// A reverse charge (AE) on invoice lines without the buyer VAT identifier
// (BT-48) or its legal registration identifier (BT-47).

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: "en16931",
  sender: seller-de,
  recipient: buyer-at + (vat-id: none),
  invoice-nr: "BR-AE-02",
)

#line-items[
  #item-with(tax.reverse-charge())
]
#payment-goal(days: 14)
#bank
