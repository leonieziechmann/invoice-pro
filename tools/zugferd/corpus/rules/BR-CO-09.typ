// expect: AGREE_INVALID BR-CO-09
//
// A seller VAT identifier (BT-31) without a country prefix.

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: "en16931",
  sender: seller-de + (vat-id: "123456788"),
  recipient: buyer-fr,
  invoice-nr: "BR-CO-09",
)

#line-items[
  #item-s
]
#payment-goal(days: 14)
#bank
