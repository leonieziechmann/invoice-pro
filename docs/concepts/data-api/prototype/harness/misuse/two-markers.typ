// Misuse: two markers in one line-items (panics with and without data).
#import "/repo/src/lib.typ": *
#show: invoice.with(
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
#line-items[
  #data.items[#item("A", price: 1)]
  #data.items[#item("B", price: 1)]
]
