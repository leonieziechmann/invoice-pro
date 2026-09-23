// Shared data of the documentation tests (tests/docs/*). Code blocks in the
// docs often elide the invoice header with a comment such as
// `// sender: .., recipient: .., invoice-nr: ..`; their tests put `..party` in
// its place. Blocks without line items are followed by `body()`.
#import "/src/lib.typ": *

#let party = (
  sender: (
    name: "Atelier Nord GmbH",
    address: "Hafenstraße 12",
    city: "20457 Hamburg",
    vat-id: "DE123456789",
    register: [Amtsgericht Hamburg HRB 123456],
    management: [Managing director: Lina Berg],
    extra: ("Phone": "+49 40 1234567", "Email": "hello@atelier-nord.de"),
  ),
  recipient: (
    name: "Muster AG",
    address: "Beispielweg 5",
    city: "80331 München",
  ),
  invoice-nr: "2026-0142",
)

#let body(n: 4) = [
  #line-items[
    #item([Corporate design concept], price: 1800)
    #item([Logo artwork], price: 650)
    #for i in range(n - 2) { item([Print run #(i + 1)], price: 240) }
  ]
  #payment-terms(days: 14)
  #bank-details(
    bank: "Hamburger Sparkasse",
    iban: "DE75512108001245126199",
    bic: "SOLADEST600",
  )
  #signature()
]
