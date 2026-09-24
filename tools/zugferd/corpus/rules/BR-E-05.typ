// expect: AGREE_INVALID BR-E-05
//
// Exempt items (E) with a rate other than 0 %, which the category does not
// allow (BT-152).

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: "en16931",
  sender: seller-de,
  recipient: buyer-fr,
  invoice-nr: "BR-E-05",
)

#line-items[
  #item-with(tax.new(
    rate: 7%,
    category: "E",
    grounds: "Steuerfrei nach § 4 Nr. 14 UStG",
  ))
]
#payment-goal(days: 14)
#bank
