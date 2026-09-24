// expect: AGREE_INVALID PEPPOL-EN16931-R110
// profiles: xrechnung
//
// An XRechnung item period (BG-26) that starts before the invoicing period
// (BG-14).

#import "_base.typ": *

#show: invoice.with(
  ..setup,
  zugferd: fixture-profile("xrechnung"),
  service-period: (
    datetime(year: 2026, month: 8, day: 1),
    datetime(year: 2026, month: 8, day: 31),
  ),
  sender: seller-de,
  recipient: buyer-de,
  invoice-nr: "PEPPOL-EN16931-R110",
)

#line-items[
  #item([Wartung], price: 100, quantity: 1, tax: tax.vat(19%), date: (
    datetime(year: 2026, month: 7, day: 15),
    datetime(year: 2026, month: 8, day: 10),
  ))
]
#payment-goal(days: 14)
#bank
