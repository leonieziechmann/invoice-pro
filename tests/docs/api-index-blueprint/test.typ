// Source: docs/docs/api-reference/index.md — "Architectural Blueprint"
// Always import the required functions and modules
#import "/src/lib.typ": *

// 1. Invoice Module: Establish the document root and global context
#show: invoice.with(
  sender: (
    name: "Acme Corp",
    address: "Industriestraße 1",
    city: "70173 Stuttgart",
    vat-id: "DE123456789", // Legally required identifier
  ),
  recipient: (name: "Jane Doe", address: "Rosenweg 12", city: "10115 Berlin"),
  invoice-nr: "INV-2026-001",
)

// 2. Line Items Module: Define the billable content
#line-items[
  #item(
    [System Architecture Consulting],
    quantity: 10,
    unit: "h",
    price: 150.00, // Unit price subject to Forward/Backward Calculation
  )
]

// 3. Components Module: Append standalone visual metadata
#payment-terms(days: 14)
#bank-details(iban: "DE75512108001245126199")
#signature()
