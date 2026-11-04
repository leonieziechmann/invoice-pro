// A binding named `data` made BEFORE `import *` (fine on 0.6.0): the glob
// import replaces it with the namespace, as it does for every new root export
// (concept L5), so `data.nr` fails. Moving the binding after the import (see
// shadow-after.typ) or renaming it is the fix.
#let data = (nr: "2026-0042")
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
  invoice-nr: data.nr,
)
#line-items[#item("Muster", price: 1)]
