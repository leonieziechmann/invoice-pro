// Source: docs/docs/api-reference/invoice/validation.md — "Levels"
#import "/src/lib.typ": *

// draft (the default): the invoice renders, the gaps are marked, a report page follows
#show: invoice.with(
  locale: locale.en-de,
  sender: (
    name: "Atelier Nord GmbH",
    address: "Hafenstraße 12",
    city: "20457 Hamburg",
    vat-id: "DE123456789",
  ),
  recipient: (name: "Muster AG"), // no address
  invoice-nr: none, // missing
  zugferd: "basic", // withheld while data is missing
  validation: "draft", // "strict" stops the build; none checks nothing
)

#line-items[
  #item([Corporate design concept], price: 1800)
]
