// expect: STRICTER IP-PERIOD-01
// finding: legal-service-period-contradiction
//
// `references.service-time(value: ..)` prints a date of its own (14.08.),
// while the XML states the date of the item (15.08., BT-72): valid XML, but
// the printed invoice contradicts it.

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: "xrechnung",
  sender: seller-de,
  recipient: buyer-de,
  invoice-nr: "RG-PERIOD-CONTRADICTS",
  references: (
    references.invoice-nr(),
    references.service-time(value: datetime(year: 2026, month: 8, day: 14)),
  ),
)

#line-items[
  #item(
    [Lieferung],
    quantity: 2,
    price: 150,
    date: datetime(year: 2026, month: 8, day: 15),
  )
]
#payment-goal(days: 14)
#bank
