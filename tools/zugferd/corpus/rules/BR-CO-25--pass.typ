// expect: AGREE_VALID
//
// A payment due date (BT-9) is enough.

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: "en16931",
  due-date: datetime(year: 2026, month: 9, day: 30),
  sender: seller-de,
  recipient: buyer-fr,
  invoice-nr: "BR-CO-25--pass",
)

#line-items[
  #item-s
]
#bank
