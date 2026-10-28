// The example invoice of the README images (scripts/readme-images): one
// invoice, branded with the made-up logo of the showcase videos, in the
// preset given by --input preset=<name>.
#import "/src/lib.typ": *

#let preset = sys.inputs.at("preset", default: "classic")

#show: invoice.with(
  theme: dictionary(theme)
    .at(preset)
    .with(theme.custom.brand(
      color: rgb("#0f766e"),
      logo: image("../videos/assets/logo.svg", alt: "Atelier Nord"),
    )),
  locale: locale.en-de,
  sender: (
    name: "Atelier Nord GmbH",
    address: "Hafenstraße 12",
    city: "20457 Hamburg",
    vat-id: "DE123456789",
  ),
  recipient: (
    name: "Acme Corporation",
    address: "Market Street 5",
    city: "80331 Munich",
  ),
  invoice-nr: "2026-0142",
)

#line-items[
  #item([Brand strategy], price: 2400)
  #item([Web design], quantity: 3, unit: unit.day, price: 900)
  #item([Photo shoot], quantity: 2, unit: unit.day, price: 650)
  #discount([Loyal customer], amount: 5%)
]

#payment-terms(days: 14)
#bank-details(
  bank: "Hamburger Sparkasse",
  iban: "DE75512108001245126199",
  bic: "SOLADEST600",
)
