// Source: docs/docs/api-reference/theme/index.md — "Quick Start"
#import "/src/lib.typ": *

#show: invoice.with(
  theme: theme.classic.with(
    theme.custom.brand(
      color: rgb("#0f766e"),
      logo: image("logo.svg", alt: "Studio Lina Berg"),
    ),
    theme.custom.marks(none), // digital only: no fold and punch marks
  ),
  locale: locale.de-de,
  sender: (
    name: "Studio Lina Berg",
    address: "Hafenstraße 12",
    city: "20457 Hamburg",
    vat-id: "DE123456789",
  ),
  recipient: (
    name: "Muster AG",
    address: "Beispielweg 5",
    city: "80331 München",
  ),
  invoice-nr: "2026-0142",
)

#line-items[
  #item([Corporate design concept], price: 1800)
  #item([Logo artwork], price: 650)
]

#payment-terms(days: 14)
