// Source: docs/docs/api-reference/invoice/country.md — "Stating the Country"
#import "/src/lib.typ": country, invoice, item, line-items, themes
#import "/tests/data-test.typ": data-test

#show: invoice.with(
  theme: themes.blank,
  sender: (
    name: "My Company GmbH",
    address: "Stubenring 1",
    city: "1010 Wien",
    country: country.at, // Customizes address format and ZUGFeRD XML
  ),
  recipient: (
    name: "US Client Inc",
    address: "123 Main St",
    city: "New York, NY 10001",
    country: "US", // The ISO code works as well
  ),
)

#data-test(test: (ctx, data) => {
  assert.eq((ctx.sender.country.code, ctx.sender.post-code), ("AT", "1010"))
  assert.eq(ctx.recipient.country.code, "US")
  assert.eq(
    (ctx.recipient.city-name, ctx.recipient.state, ctx.recipient.post-code),
    ("New York", "NY", "10001"),
  )
  assert.eq(ctx.recipient.city, [New York, NY 10001 \ ] + "US - United States")
})[
  #line-items[#item([Consulting], price: 100)]
]
