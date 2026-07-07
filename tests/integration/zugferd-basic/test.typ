#import "/src/lib.typ": *

#show: invoice.with(
  theme: themes.DIN-5008(font: "libertinus serif"),
  locale: locale.de-de,
  zugferd: "en16931",
  sender: (
    name: "Test GmbH",
    address: "Musterstraße 1",
    city: "12345 Musterstadt",
    tax-nr: "123/456/78901",
    vat-id: "DE123456789",
    extra: ("USt-IdNr.": "DE123456789"),
  ),
  recipient: (
    name: "Kunde AG",
    address: "Kundenweg 5",
    city: "54321 Kundenstadt",
    tax-nr: "987/654/32109",
    vat-id: "DE987654321",
  ),
  invoice-nr: "ZUG-2026-001",
  date: datetime(year: 2026, month: 7, day: 6),
)

#line-items[
  #item([Beratungsleistung], price: 100.00, quantity: 10, unit: "hrs")
  #item(
    [Software-Lizenz],
    price: 49.90,
    quantity: 2,
    unit: "pcs",
    tax: tax.exempt(grounds: "I like money."),
  )
]

#payment-goal(days: 14)

#bank-details(
  bank: "Musterbank",
  iban: "DE07100202005821158846",
  bic: "BHBLDEHHXXX",
)

#signature()
