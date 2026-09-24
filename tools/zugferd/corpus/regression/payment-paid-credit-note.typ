// expect: AGREE_VALID
// finding: legal-paid-credit-note-sentence
//
// A credit note its sender paid out in cash: the printed sentence and the
// payment terms (BT-20) say that the sender paid the amount to the
// recipient, not that the recipient paid it.

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: "xrechnung",
  document-type: "credit-note",
  sender: seller-de,
  recipient: buyer-de,
  invoice-nr: "GS-PAID",
  preceding-invoice-nr: "RG-2026-11",
  preceding-invoice-date: datetime(year: 2026, month: 8, day: 3),
)

#line-items[
  #item([Rückerstattung Wartung], quantity: 2, unit: unit.hour, price: 95)
]
#paid(method: "cash", date: datetime(year: 2026, month: 9, day: 1))
