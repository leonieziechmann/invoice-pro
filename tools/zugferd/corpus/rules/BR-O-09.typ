// expect: AGREE_INVALID BR-O-09
// profiles: basic-wl basic en16931 xrechnung
//
// Items not subject to VAT (O) with a VAT rate.

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: fixture-profile("en16931"),
  sender: seller-de + (vat-id: none),
  recipient: buyer-us,
  invoice-nr: "BR-O-09",
)

#line-items[
  #item-with(tax.new(
    rate: 19%,
    category: "O",
    grounds: "Nicht im Inland steuerbar",
  ))
]
#payment-goal(days: 14)
#bank
