// Source: docs/docs/b2b.md — "1. National B2B Invoice (Standard VAT)"
// Compile-only: the example must compile as documented (it used to
// carry an invalid IBAN).
#import "/src/lib.typ": *

#show: invoice.with(
  locale: locale.de-de,
  // Default tax mode is "exclusive" (net prices), so this can be omitted,
  // but you can declare it explicitly for clarity:
  tax-mode: "exclusive",
  tax: tax.vat(19%), // Apply standard German VAT

  sender: (
    name: "Tech Solutions GmbH",
    address: "Software Allee 10",
    city: "80331 München",
    country: country.de,
    tax-nr: "143/123/45678",
    vat-id: "DE123456789",
    contact: (
      name: "Max Mustermann",
      phone: "+49 89 123456",
      email: "billing@techsolutions.de",
    ),
    extra: (
      "Geschäftsführer": "Max Mustermann",
      "Handelsregister": "Amtsgericht München, HRB 987654",
    ),
  ),

  recipient: (
    name: "Logistics Experts AG",
    address: "Industriestraße 42",
    city: "70173 Stuttgart",
    country: country.de,
    vat-id: "DE987654321",
  ),

  invoice-nr: "INV-2026-0089",
  date: datetime(year: 2026, month: 7, day: 9),
  // The period of the supply, printed by `references.service-time()`
  service-period: (
    datetime(year: 2026, month: 6, day: 1),
    datetime(year: 2026, month: 6, day: 30),
  ),
  references: (
    references.service-time(),
    ("Bestellnummer", "PO-99120"),
  ),
)

= Projektberatung und Entwicklung

#line-items[
  #item([IT-Architektur Beratung], quantity: 15, unit: unit.hour, price: 120.00)
  #item(
    [Backend Softwareentwicklung],
    quantity: 40,
    unit: unit.hour,
    price: 95.00,
  )
  #item(
    [Server-Setup & Deployment],
    quantity: 1,
    unit: unit.piece,
    price: 450.00,
  )
]

#payment-goal(days: 14)

#bank-details(
  bank: "Commerzbank",
  iban: "DE89370400440532013000",
  bic: "COBADEFFXXX",
)
