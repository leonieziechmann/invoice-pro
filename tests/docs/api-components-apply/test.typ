// Source: docs/docs/api-reference/components.md — "Example: Bulk Tax Application"
// The block elides the document (`// ...`); the test puts the apply block into line-items.
#import "/tests/docs/prelude.typ": *

#show: invoice.with(..party)

#line-items[
  #apply(tax: tax.vat(7%))[
    #item(
      [Textbook: "Modern Web Design"],
      price: 49.90,
      quantity: 2,
    )
    #item(
      [Textbook: "SEO for Beginners"],
      price: 29.90,
    )
  ]
]
