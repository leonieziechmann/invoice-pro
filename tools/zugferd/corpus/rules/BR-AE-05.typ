// expect: AGREE_INVALID BR-AE-05
//
// A reverse charge (AE) with a rate other than 0 %, which the category does
// not allow (BT-152).

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: "en16931",
  sender: seller-de,
  recipient: buyer-at,
  invoice-nr: "BR-AE-05",
)

#line-items[
  #item-with(tax.new(rate: 19%, category: "AE", grounds: "Reverse charge"))
]
#payment-goal(days: 14)
#bank
