// An explicit level keeps its meaning when hydrated: `validation: "draft"`
// (a deliberate debug choice) renders the draft of incomplete data. With
// `--input level=auto` and no data: the default level of 0.6.0, a draft.
#import "/repo/src/lib.typ": *
#let level = sys.inputs.at("level", default: "draft")
#show: invoice.with(
  data: data.load(read: p => read(p, encoding: none)),
  validation: if level == "auto" { auto } else { level },
  sender: (
    name: "ACME GmbH",
    address: "Weg 1",
    city: "80331 München",
    country: "DE",
    vat-id: "DE123456789",
  ),
  recipient: (name: "Muster", address: "Musterweg 1", city: "10115 Berlin"),
)
#line-items[#item("Muster", price: 1)]
#payment(terms: (days: 14), bank: (iban: "DE75512108001245126199"))
