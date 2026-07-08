#import "/src/lib.typ": *

#show: invoice.with(
  // Enable the comfort EN 16931 e-invoicing profile
  zugferd: "en16931",

  sender: (
    name: "Consulting Group GmbH",
    address: "Tech Avenue 42",
    city: "80331 München",
    country: country.de,
    tax-nr: "143/123/45678",
    vat-id: "DE123456789",
  ),

  recipient: (
    name: "Acme Corp",
    address: "Industrial Road 1",
    city: (name: "Stuttgart", post-code: "70173"),
    country: country.de,
    vat-id: "DE987654321",
  ),

  invoice-nr: "INV-2026-102",
  date: datetime(year: 2026, month: 7, day: 8),

  tax-mode: "exclusive",
  tax: tax.vat(19%),
)

= Project Deliverables

#line-items[
  // Using a predefined unit from the unit module (resolved dynamically)
  #item(
    [Senior Software Development],
    quantity: 40,
    unit: unit.hour,
    price: 120.00,
  )

  // Using a custom/dictionary unit code
  #item(
    [On-site Workshop Bundle],
    quantity: 1,
    unit: (display: "Pkg.", code: "C62"),
    price: 1500.00,
  )

  // Applying standard tax exemption
  #item(
    [VAT-Free Educational Materials],
    quantity: 5,
    unit: (display: "Pcs.", code: "C62"),
    price: 45.00,
    tax: tax.exempt(grounds: "Section 4 No. 21 UStG"),
  )
]

#bank-details(
  bank: "Global Business Bank",
  iban: "DE89370400440532013000",
  bic: "GBBADEFFXXX",
)
