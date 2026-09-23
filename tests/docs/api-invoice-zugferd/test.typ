// Source: docs/docs/api-reference/invoice/index.md — "zugferd — ZUGFeRD / Factur-X"
#import "/tests/docs/prelude.typ": *

#show: invoice.with(
  zugferd: "en16931",
  sender: (
    name: "Musterfirma GmbH",
    address: "Musterstraße 1",
    city: "12345 Musterstadt",
    vat-id: "DE123456789",
    contact: (
      name: "Max Mustermann",
      phone: "+49 123 456789",
      email: "max@musterfirma.de",
    ),
  ),
  recipient: (
    name: "Kunde AG",
    address: "Kundenweg 5",
    city: "54321 Kundenstadt",
    vat-id: "DE987654321",
    buyer-reference: "DE123456789-12345-12",
  ),
  invoice-nr: "INV-2026-001",
)

#body()
