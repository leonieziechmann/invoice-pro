// expect: AGREE_INVALID
// finding: fidelity-cat-rate-checks-m-o
//
// A supply not subject to VAT (category O) cannot carry a VAT rate
// (BR-O-05, BR-O-09); `tax.new` allows to state one. invoice-pro wrote the
// 19 % without a report.

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: "en16931",
  sender: seller-de + (vat-id: none),
  recipient: buyer-us,
  invoice-nr: "RG-O-RATE",
)

#line-items[
  #item(
    [Leistung],
    price: 100,
    quantity: 2,
    tax: tax.new(
      rate: 19%,
      category: "O",
      grounds: "Nicht im Inland steuerbar",
    ),
  )
]
#payment-goal(days: 14)
#bank
