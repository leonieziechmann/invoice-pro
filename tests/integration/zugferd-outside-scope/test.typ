#import "/src/lib.typ": *

#show: invoice.with(
  theme: themes.DIN-5008(font: "libertinus serif"),
  locale: locale.de-de,
  zugferd: "en16931",
  sender: (
    name: "Consulting GmbH",
    address: "Musterstraße 1",
    city: "12345 Musterstadt",
    tax-nr: "123/456/78901",
    vat-id: "DE123456789",
    contact: (
      name: "Max Mustermann",
      phone: "+49 123 456789",
      email: "max@mustermann.de",
    ),
    extra: ("Steuernummer": "123/456/78901"),
  ),
  recipient: (
    name: "Kunde AG",
    address: "Kundenweg 5",
    city: "54321 Kundenstadt",
    buyer-reference: "DE123456789-12345-12",
    contact: (
      name: "Einkauf",
      email: "accounting@kunde.de",
    ),
  ),
  invoice-nr: "ZUG-OUT-2026-001",
  date: datetime(year: 2026, month: 7, day: 6),
  tax: tax.outside-scope(grounds: "Nicht steuerbare Leistung."),
)

#line-items[
  #item([Internationale Beratung], price: 150.00, quantity: 4, unit: "hrs")
  #item([Support-Leistung], price: 50.00, quantity: 2, unit: "hrs")
]

#payment-goal(days: 14)

#bank-details(
  bank: "Musterbank",
  iban: "DE75512108001245126199",
  bic: "SOLADEST600",
)

#signature()
