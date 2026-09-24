// expect: AGREE_INVALID BR-56
//
// A seller tax representative (BG-11) without a VAT identifier (BT-63).

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: "en16931",
  sender: seller-de + (tax-representative: representative + (vat-id: none)),
  recipient: buyer-fr,
  invoice-nr: "BR-56",
)

#line-items[
  #item-s
]
#payment-goal(days: 14)
#bank
