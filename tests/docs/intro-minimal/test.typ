// Source: docs/docs/intro.md — "Quick Glance"
#import "/src/lib.typ": *

#show: invoice.with(
  // Set the locale for language, formatting, and legal behaviors
  locale: locale.en-de,
  sender: (
    name: "Consulting Group LLC",
    address: "Consulting Street 1",
    city: "10115 Berlin",
    vat-id: "DE123456789",
  ),
  recipient: (
    name: "Acme Corp",
    address: "Acme Street 1",
    city: "80331 Munich",
  ),
  invoice-nr: "INV-2026-001",
)

// A strictly scoped block where children inherit parameters automatically
#line-items[
  #item([Strategic IT Consulting], quantity: 10, unit: unit.h, price: 150.00)
  #item([Server Infrastructure Audit], price: 1200.00)
  #item([Cloud Migration Support], quantity: 5, unit: unit.h, price: 120.00)

  // Modifiers automatically apply to the context they are placed in
  #discount([Long-term Client Discount], amount: 10%)
]

// Automated bank details with QoL payment features
#bank-details(
  bank: "Example Bank",
  iban: "DE75512108001245126199",
  bic: "SOLADEST600",
)
