// Source: docs/docs/themes/technical.md — "Quick Start"
#import "/src/lib.typ": *

#show: invoice.with(
  theme: theme.technical,
  locale: locale.en-de,
  sender: (
    name: "Brückner & Yildiz Software GmbH",
    address: "Schlesische Straße 26",
    city: "10997 Berlin",
    vat-id: "DE298765431",
    register: [Local court Charlottenburg, HRB 214365 B],
    management: [Managing directors: Jana Brückner, Emre Yildiz],
    extra: (Email: "billing@by-software.de", Web: "by-software.de"),
  ),
  recipient: (
    name: "Hansa Logistik AG",
    address: "Am Speicher XI 4",
    city: "28217 Bremen",
  ),
  invoice-nr: "BY-2026-0917",
  customer-nr: "C-0042",
  project: "DISPATCH-NG",
  references: (references.customer-nr(), references.project()),
)

#line-items[
  #group([Sprint 14, 1–14 September])[
    #item(
      [Backend development],
      description: [REST API v3, OpenAPI spec, contract tests],
      quantity: 38,
      unit: "h",
      price: 115,
    )
    #item([Frontend development], quantity: 26, unit: "h", price: 105)
  ]
  #item(
    [Kubernetes cluster operations, September],
    quantity: 1,
    unit: "month",
    price: 890,
  )
]

#payment-terms(days: 30)
#bank-details(
  bank: "Berliner Sparkasse",
  iban: "DE75512108001245126199",
  bic: "SOLADEST600",
)
