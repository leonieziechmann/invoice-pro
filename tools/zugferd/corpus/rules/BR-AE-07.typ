// expect: AGREE_INVALID BR-AE-07
//
// A reverse charge (AE) with a rate other than 0 %, which the category does
// not allow (BT-103), on a document level charge. BASIC WL has no lines, so
// the rule of the allowance or charge applies.

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: "basic-wl",
  sender: seller-de,
  recipient: buyer-at,
  invoice-nr: "BR-AE-07",
)

#line-items[
  #item-with(tax.new(rate: 19%, category: "AE", grounds: "Reverse charge"))
  #shipping
]
#payment-goal(days: 14)
#bank
