// ONE invoice body shared by every test.
#import "/src/lib.typ": *
#import "/tests/test-locale.typ": test-locale

#let logo-img = box(
  width: 34mm,
  height: 11mm,
  fill: rgb("#0f766e"),
  radius: 2pt,
  align(center + horizon, text(
    fill: white,
    weight: "bold",
    size: 11pt,
  )[ATELIER·NORD]),
)

#let party = (
  sender: (
    name: "Atelier Nord GmbH",
    address: "Hafenstraße 12",
    city: "20457 Hamburg",
    vat-id: "DE123456789",
    register: [Amtsgericht Hamburg HRB 123456],
    management: [GF: Lina Berg],
    extra: (Telefon: "+49 40 1234567", "E-Mail": "hallo@atelier-nord.de"),
  ),
  recipient: (
    name: "Muster AG",
    address: "Beispielweg 5",
    city: "80331 München",
  ),
  invoice-nr: "2026-0142",
  customer-nr: "K-2201",
  references: (references.customer-nr(), references.vat-id()),
)

#let body(n: 4) = [
  Sehr geehrte Damen und Herren, für unsere Leistungen im September berechnen wir:

  #line-items[
    #item(
      [Konzeption Corporate Design],
      price: 1800,
      description: [Workshops, Moodboards, zwei Entwurfsrunden],
    )
    #item([Logo-Reinzeichnung], price: 650)
    #item([Geschäftsausstattung], price: 95, quantity: 4, modifier: discount(
      [Paketrabatt],
      amount: 10%,
    ))
    #for i in range(n - 3) { item([Druckabwicklung #(i + 1)], price: 240) }
  ]

  #payment-terms(days: 14)
  #bank-details(
    bank: "Hamburger Sparkasse",
    iban: "DE75512108001245126199",
    bic: "SOLADEST600",
  )
  #signature()
]
