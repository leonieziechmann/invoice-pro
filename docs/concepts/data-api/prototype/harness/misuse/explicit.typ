// R7: an explicit value plus a CLI input = two sources.
#import "/repo/src/lib.typ": *
#show: invoice.with(
  data: json("../data/2026-0042.json"),
  sender: (
    name: "ACME GmbH",
    address: "Weg 1",
    city: "80331 München",
    country: "DE",
    vat-id: "DE123456789",
  ),
  recipient: (name: "Muster", address: "Musterweg 1", city: "10115 Berlin"),
  invoice-nr: "MUSTER-0001",
)
#line-items[#item("Muster", price: 1)]
#payment(terms: (days: 14), bank: (iban: "DE75512108001245126199"))
