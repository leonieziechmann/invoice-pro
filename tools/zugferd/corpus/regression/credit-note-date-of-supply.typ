// expect: AGREE_VALID
// finding: legal-credit-note-date-of-supply
// facts: {"type_code": "381", "period": ["20260801", "20260831"]}
//
// A credit note amends an invoice, so its own date is not the date of the
// supply: without dates it states none (see credit-note-xrechnung, where
// XRechnung only informs about it, BR-DE-TMP-32). With the `service-period`
// of the supply it credits, the printed credit note and the XML (BG-14)
// state that period.

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: "xrechnung",
  document-type: "credit-note",
  sender: seller-de,
  recipient: buyer-de,
  invoice-nr: "RK-2026-18",
  preceding-invoice-nr: "R-2026-11",
  service-period: (
    datetime(year: 2026, month: 8, day: 1),
    datetime(year: 2026, month: 8, day: 31),
  ),
)

#line-items[
  #item([Wartung August], quantity: 2, unit: unit.hour, price: 95)
]
#payment-goal(days: 14)
#bank-details(bank: "Kundenbank", iban: "DE75512108001245126199")
