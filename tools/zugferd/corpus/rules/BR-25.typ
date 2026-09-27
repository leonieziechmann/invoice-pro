// expect: AGREE_INVALID BR-25
// profiles: basic en16931 xrechnung
//
// An item whose name (BT-153) has no text.

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: fixture-profile("en16931"),
  sender: seller-de,
  recipient: buyer-fr,
  invoice-nr: "BR-25",
)

#line-items[
  #item([], price: 100, quantity: 1, tax: tax.vat(19%))
]
#payment-goal(days: 14)
#bank
