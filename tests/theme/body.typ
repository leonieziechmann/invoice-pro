// The ONE invoice body shared by the theme tests (ported from the theming
// prototype's tests/body.typ): a German design studio, a box logo, four items.
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

// The theme presets and layouts by name (the prototype's --input look=/layout=).
#let presets = (
  "classic",
  "plain",
  "corporate",
  "elegant",
  "prestige",
  "bold",
  "technical",
  "soft",
  "compact",
  "boxed",
)
#let layouts = (
  "din-5008-a",
  "din-5008-b",
  "us-letter-10",
  "a4-digital",
  "us-letter-digital",
  "sn-010130-right",
  "sn-010130-left",
  "a4-window-right",
  "a4-window-left",
  "plain",
  "a4-sidebar",
  "us-letter-sidebar",
  "a4-band",
  "us-letter-band",
  "a4-dense",
  "us-letter-dense",
)
#let preset-of(name) = dictionary(theme).at(name)
#let layout-of(name) = if name == auto or name == "auto" { auto } else {
  dictionary(theme.layout).at(name)
}

// The layout `layout: auto` picks per preset and SENDER region (the maintainer's
// mapping, concept §8.4 and §9).
#let auto-layout(look, region) = {
  let window = (
    de: "din-5008-a",
    at: "din-5008-b",
    ch: "sn-010130-right",
    fr: "a4-window-right",
    it: "a4-window-right",
    es: "a4-window-right",
    gb: "a4-window-left",
    us: "us-letter-10",
  ).at(region, default: "din-5008-a")
  let us = region == "us"
  (
    classic: window,
    boxed: window,
    // the centred serif letterhead needs form B's zone: form A becomes form B
    elegant: if window == "din-5008-a" { "din-5008-b" } else { window },
    corporate: if us { "us-letter-sidebar" } else { "a4-sidebar" },
    prestige: if us { "us-letter-band" } else { "a4-band" },
    bold: if us { "us-letter-digital" } else { "a4-digital" },
    technical: if us { "us-letter-digital" } else { "a4-digital" },
    soft: if us { "us-letter-digital" } else { "a4-digital" },
    compact: if us { "us-letter-dense" } else { "a4-dense" },
    plain: "plain",
  ).at(look)
}
