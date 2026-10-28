// Source: docs/docs/themes/elegant.md — "Quick Start"
#import "/src/lib.typ": *

#show: invoice.with(
  theme: theme.elegant,
  locale: locale.en-de,
  sender: (
    name: "Brenner & Voss Attorneys at Law",
    address: "Jungfernstieg 30",
    city: "20354 Hamburg",
    vat-id: "DE318273645",
    register: [Partnership register Hamburg, PR 1187],
    extra: (Phone: "+49 40 3570 880", Email: "office@brenner-voss.de"),
  ),
  recipient: (
    name: "Halden Shipping GmbH",
    address: "Große Elbstraße 145",
    city: "22767 Hamburg",
  ),
  invoice-nr: "BV-2026-0412",
  subject: "Fee note, Halden v. Norrmar (charter dispute)",
)

#line-items[
  #item(
    [Review of the charter party and correspondence],
    quantity: 6.5,
    unit: unit.hour,
    price: 320,
  )
  #item(
    [Statement of claim, Hamburg Regional Court],
    quantity: 11,
    unit: unit.hour,
    price: 320,
  )
  #item([Travel expenses, hearing in Bremen], price: 186.4)
]

#payment-terms(days: 14)
#bank-details(
  bank: "Hamburger Sparkasse",
  iban: "DE75512108001245126199",
  bic: "SOLADEST600",
)
#signature(name: "Dr. Helena Brenner")
