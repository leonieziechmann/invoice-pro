// Coverage: data items but no line-items, data payment but no payment(..).
#import "/repo/src/lib.typ": *
#show: invoice.with(
  data: data.load(read: p => read(p, encoding: none)),
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
#payment-terms(days: 14)
