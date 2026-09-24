// expect: AGREE_INVALID BR-G-06
//
// An export outside the EU (G) with a rate other than 0 %, which the category
// does not allow (BT-96), on a document level allowance. BASIC WL has no
// lines, so the rule of the allowance or charge applies.

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: "basic-wl",
  sender: seller-de,
  recipient: buyer-us,
  invoice-nr: "BR-G-06",
)

#line-items[
  #item-with(tax.new(
    rate: 19%,
    category: "G",
    grounds: "Steuerfreie Ausfuhrlieferung",
  ))
  #rebate
]
#payment-goal(days: 14)
#bank
