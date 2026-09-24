// expect: AGREE_INVALID BR-17
// profiles: basic-wl basic en16931 xrechnung
//
// A payee (BG-10) without a name (BT-59), identified by its identifier
// (BT-60) only.

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: fixture-profile("basic-wl"),
  payee: (id: "PAY-4711"),
  sender: seller-de,
  recipient: buyer-fr,
  invoice-nr: "BR-17--no-name",
)

#line-items[
  #item-s
]
#payment-goal(days: 14)
#bank
