// The docs prelude of the concept's typst snippets (the theming prototype's
// tests/doc/prelude.typ): the header data `doc-party` and `doc-body()`.
#import "/src/lib.typ": *

#let doc-party = (
  sender: (
    name: "Atelier Nord GmbH",
    address: "Hafenstraße 12",
    city: "20457 Hamburg",
    vat-id: "DE123456789",
    email: "hallo@atelier-nord.de",
    register: [Amtsgericht Hamburg HRB 123456],
    management: [GF: Lina Berg],
    extra: (Telefon: "+49 40 1234567"),
  ),
  recipient: (
    name: "Muster AG",
    address: "Beispielweg 5",
    city: "80331 München",
    email: "ap@muster.de",
  ),
  invoice-nr: "2026-0142",
  customer-nr: "K-2201",
)
#let doc-body(n: 4) = [
  Sehr geehrte Damen und Herren, für unsere Leistungen berechnen wir:
  #line-items[
    #item([Konzeption Corporate Design], price: 1800)
    #item([Logo-Reinzeichnung], price: 650)
    #for i in range(n - 2) { item([Druckabwicklung #(i + 1)], price: 240) }
  ]
  #payment-terms(days: 14)
  #bank-details(
    bank: "Hamburger Sparkasse",
    iban: "DE75512108001245126199",
    bic: "SOLADEST600",
  )
  #signature()
]
