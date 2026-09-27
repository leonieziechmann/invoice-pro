// expect: AGREE_INVALID BR-G-05
// profiles: basic en16931 xrechnung
//
// An export outside the EU (G) with a rate other than 0 %, which the category
// does not allow (BT-152).

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: fixture-profile("en16931"),
  sender: seller-de,
  recipient: buyer-us,
  invoice-nr: "BR-G-05",
)

#line-items[
  #item-with(tax.new(
    rate: 19%,
    category: "G",
    grounds: "Steuerfreie Ausfuhrlieferung",
  ))
]
#payment-goal(days: 14)
#bank
