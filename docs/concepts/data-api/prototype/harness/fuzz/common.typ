#let zf = sys.inputs.at("zf", default: "none")
#let zugf = if zf == "none" { none } else if zf == "auto" { auto } else { zf }
#let sender = (
  name: "ACME GmbH",
  address: "Weg 1",
  city: "80331 München",
  country: "DE",
  vat-id: "DE123456789",
)
#let rcpt = (
  name: "Edge AG",
  address: "Kante 1",
  city: "50667 Köln",
  country: "DE",
  vat-id: "DE811128135",
)
