// Source: docs/docs/e-invoicing.md — "12. Item Notes, Periods and
// Country of Origin"
// Compile-only: the example must compile as documented, with an
// e-invoice without errors.
#import "/src/lib.typ": *

#show: invoice.with(
  zugferd: "en16931",
  sender: (
    name: "Consulting Group GmbH",
    address: "Tech Avenue 42",
    city: "80331 München",
    country: country.de,
    vat-id: "DE123456789",
    contact: (
      name: "Max Mustermann",
      phone: "+49 89 1234567",
      email: "max@consultinggroup.de",
    ),
  ),
  recipient: (
    name: "Acme Corp",
    address: "Industrial Road 1",
    city: "70173 Stuttgart",
    country: country.de,
    vat-id: "DE987654321",
  ),
  invoice-nr: "INV-2026-118",
  date: datetime(year: 2026, month: 9, day: 1),
)

#line-items[
  #item(
    [Espresso machine],
    price: 1290.00,
    tax: tax.vat(19%),
    date: datetime(year: 2026, month: 8, day: 3),
    note: "Serial number 4711-0815",
    origin: country.it,
  )
  #item(
    [Barista training],
    quantity: 2,
    unit: unit.day,
    price: 450.00,
    tax: tax.vat(19%),
    date: (
      datetime(year: 2026, month: 8, day: 10),
      datetime(year: 2026, month: 8, day: 11),
    ),
  )
]

#payment-goal(days: 14)

#bank-details(
  bank: "Acme Bank",
  iban: "DE89370400440532013000",
)
