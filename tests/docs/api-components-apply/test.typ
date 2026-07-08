// Source: docs/docs/api-reference/components.md — "Bulk Tax Application" (apply)
#import "/src/lib.typ": *

#show: invoice.with(
  theme: themes.DIN-5008(font: "libertinus serif"),
  sender: (name: "Test Sender"),
  recipient: (name: "Test Recipient"),
)

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
