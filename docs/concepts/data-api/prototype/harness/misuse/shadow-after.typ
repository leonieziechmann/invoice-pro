// A binding named `data` made AFTER `import *` wins over the namespace (the
// documented caveat: `data.load` is then out of reach), and invoice(data:)
// still takes the raw dictionary.
#import "/repo/src/lib.typ": *
#let data = json("../data/2026-0042.json")
#show: invoice.with(
  data: data,
  sender: (
    name: "ACME GmbH",
    address: "Weg 1",
    city: "80331 München",
    country: "DE",
    vat-id: "DE123456789",
  ),
)
#line-items[]
#payment(
  terms: (days: 14),
  bank: (iban: "DE75512108001245126199"),
  creditor-id: "DE98ZZZ09999999999",
)
