// Source: docs/docs/e-invoicing.md — "9. Document Type (BT-3)"
// Compile-only: the credit note must compile as documented, with an
// e-invoice without errors.
#import "/src/lib.typ": *

#show: invoice.with(
  zugferd: auto,
  document-type: "credit-note",
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
    buyer-reference: "DE123456789-12345-12",
  ),
  invoice-nr: "CN-2026-007",
  date: datetime(year: 2026, month: 7, day: 20),
  preceding-invoice-nr: "INV-2026-102",
)

#line-items[
  #item(
    [Workshop cancelled by us],
    quantity: 1,
    price: 1500.00,
    tax: tax.vat(19%),
  )
]

#payment-goal(days: 14)

#bank-details(
  bank: "Acme Bank",
  iban: "DE89370400440532013000",
)
