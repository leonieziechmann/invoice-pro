// R7: data: none while the CLI hands over data.
#import "/repo/src/lib.typ": *
#show: invoice.with(
  data: none,
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
