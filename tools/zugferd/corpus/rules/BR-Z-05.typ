// expect: AGREE_INVALID BR-Z-05
//
// Zero rated items (Z) with a rate other than 0 %, which the category does not
// allow (BT-152).

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: "en16931",
  sender: seller-de,
  recipient: buyer-fr,
  invoice-nr: "BR-Z-05",
)

#line-items[
  #item-with(tax.new(rate: 7%, category: "Z"))
]
#payment-goal(days: 14)
#bank
