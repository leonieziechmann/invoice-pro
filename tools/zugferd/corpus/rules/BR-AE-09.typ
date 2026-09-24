// expect: AGREE_INVALID BR-AE-09
// profiles: basic-wl
//
// A reverse charge (AE) with a rate other than 0 %, which the category does
// not allow: in BASIC WL, without lines, its VAT breakdown states a VAT amount
// (BT-117) other than 0.

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: fixture-profile("basic-wl"),
  sender: seller-de,
  recipient: buyer-at,
  invoice-nr: "BR-AE-09",
)

#line-items[
  #item-with(tax.new(rate: 19%, category: "AE", grounds: "Reverse charge"))
]
#payment-goal(days: 14)
#bank
