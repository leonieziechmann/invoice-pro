// Source: docs/docs/api-reference/index.md — "Architectural Blueprint"
#import "/src/lib.typ": *

// 1. Invoice Module: Establish the document root and global context
#show: invoice.with(
  theme: themes.DIN-5008(font: "libertinus serif"),
  sender: (name: "Acme Corp"),
  recipient: (name: "Jane Doe"),
  tax-nr: "DE123456789", // Legally required identifier
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
#payment-goal(days: 14)
#bank-details(iban: "DE75512108001245126199")
#signature()
