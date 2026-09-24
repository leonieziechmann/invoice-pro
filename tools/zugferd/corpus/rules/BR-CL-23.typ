// expect: AGREE_INVALID BR-CL-23
// profiles: basic en16931 xrechnung
//
// A unit code (BT-130) outside UN/ECE Recommendation 20.

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: fixture-profile("en16931"),
  sender: seller-de,
  recipient: buyer-fr,
  invoice-nr: "BR-CL-23",
)

#line-items[
  #item(
    [Kisten],
    price: 100,
    quantity: 1,
    unit: (display: "Kiste", code: "KST"),
    tax: tax.vat(19%),
  )
]
#payment-goal(days: 14)
#bank
