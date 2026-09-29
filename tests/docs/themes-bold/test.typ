// Source: docs/docs/themes/bold.md — "Quick Start"
#import "/src/lib.typ": *

#show: invoice.with(
  theme: theme.bold,
  locale: locale.en-de,
  sender: (
    name: "Kiln Studio GmbH",
    address: "Lohmühlenstraße 65",
    city: "12435 Berlin",
    vat-id: "DE326598741",
    register: [Local court Charlottenburg, HRB 219876 B],
    extra: (Email: "studio@kiln.studio", Web: "kiln.studio"),
  ),
  recipient: (
    name: "Sonar Audio GmbH",
    address: "Schanzenstraße 22",
    city: "20357 Hamburg",
  ),
  invoice-nr: "KS-2026-044",
)

#line-items[
  #item([Brand strategy and positioning], price: 3200)
  #item(
    [Visual identity system],
    description: [Logo suite, grid, iconography, brand guidelines],
    price: 6500,
  )
  #item(
    [Motion identity: logo animations],
    quantity: 3,
    unit: unit.piece,
    price: 850,
  )
  #discount([Package discount], amount: 5%)
]

#payment-terms(days: 14)
#bank-details(
  bank: "GLS Bank",
  iban: "DE75512108001245126199",
  bic: "SOLADEST600",
)
