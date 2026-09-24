// expect: AGREE_INVALID BR-30
// profiles: basic en16931 xrechnung
//
// An item period (BG-26) that ends before it starts.

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: fixture-profile("en16931"),
  sender: seller-de,
  recipient: buyer-fr,
  invoice-nr: "BR-30",
)

#line-items[
  #item([Wartung], price: 100, quantity: 1, tax: tax.vat(19%), date: (
    datetime(year: 2026, month: 8, day: 31),
    datetime(year: 2026, month: 8, day: 1),
  ))
]
#payment-goal(days: 14)
#bank
