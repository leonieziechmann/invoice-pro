// Source: docs/docs/api-reference/invoice/index.md — "sender & recipient"
#import "/tests/docs/prelude.typ": *

#show: invoice.with(
  sender: (
    name: "Max Mustermann",
    address: ("Musterstraße 1", "Hinterhaus 2"),
    city: "12345 Musterstadt",
    vat-id: "DE123456789",
    register: [Amtsgericht Musterstadt, HRB 12345],
    management: [Managing director: Max Mustermann],
    extra: (
      "Phone": "+49 123 456789",
      "Email": "max@mustermann.de",
      "Web": "www.mustermann.de",
    ),
  ),
  recipient: (
    name: "Acme Corporation",
    address: "Business Blvd 42",
    city: "54321 Metropolis",
    extra: (
      ("Contact Person", "Jane Doe"),
      ("Department", "Accounting"),
    ),
  ),
  invoice-nr: "2026-0142",
)
#body()
