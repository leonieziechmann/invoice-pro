// Source: docs/docs/api-reference/invoice.md — "Minimal Valid Configuration"
#import "/src/lib.typ": *

#show: invoice.with(
  theme: themes.DIN-5008(font: "libertinus serif"),
  sender: (
    name: "Max Mustermann",
    address: "Musterstraße 1",
    city: "12345 Musterstadt",
    vat-id: "DE123456789",
  ),
  recipient: (
    name: "Acme Corporation",
    address: "Business Blvd 42",
    city: "54321 Metropolis",
  ),
  invoice-nr: "INV-2026-001",
)

// The document body starts here
#line-items[
  #item(
    [Consulting Services],
    quantity: 10,
    unit: "h",
    price: 150.00,
  )
]
