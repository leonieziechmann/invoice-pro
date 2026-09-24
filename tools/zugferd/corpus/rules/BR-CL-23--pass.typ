// expect: AGREE_VALID
// profiles: en16931
//
// A unit code of UN/ECE Recommendation 20.

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: fixture-profile("en16931"),
  sender: seller-de,
  recipient: buyer-fr,
  invoice-nr: "BR-CL-23--pass",
)

#line-items[
  #item(
    [Kisten],
    price: 100,
    quantity: 1,
    unit: (display: "Stück", code: "H87"),
    tax: tax.vat(19%),
  )
]
#payment-goal(days: 14)
#bank
