// expect: AGREE_INVALID BR-Z-02
//
// Zero rated items (Z) on invoice lines without the seller VAT identifier
// (BT-31) or tax number (BT-32).

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: "en16931",
  sender: seller-de-id,
  recipient: buyer-fr,
  invoice-nr: "BR-Z-02",
)

#line-items[
  #item-with(tax.zero())
]
#payment-goal(days: 14)
#bank
