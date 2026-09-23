// Source: docs/docs/api-reference/invoice/country.md — "Countries Outside the
// Module" and "Post Codes"
#import "/src/lib.typ": *
#import "/tests/data-test.typ": data-test

#let norway = country.custom(code: "NO", name: "Norge", post-code: "9999")
#let canada = country.custom(
  code: "CA",
  name: "Canada",
  post-code: "A9A 9A9",
  post-code-position: "after",
)

#show: invoice.with(
  theme: themes.blank,
  sender: (
    name: "My Company GmbH",
    address: "Stubenring 1",
    city: "1010 Wien",
    country: country.at,
  ),
  recipient: (
    name: "Eksempel AS",
    address: "Karl Johans gate 1",
    city: "0154 Oslo",
    country: norway,
  ),
)

#data-test(test: (ctx, data) => {
  assert.eq(ctx.sender.post-code, "1010")
  assert.eq(ctx.recipient.country.code, "NO")
  assert.eq(
    (ctx.recipient.post-code, ctx.recipient.city-name),
    ("0154", "Oslo"),
  )
  assert.eq(ctx.recipient.city, [0154 Oslo \ ] + "NO - Norge")

  let parsed = (canada.parse-city)("Toronto ON M5V 2T6")
  assert.eq((parsed.post-code, parsed.name), ("M5V 2T6", "Toronto ON"))

  // "Post Codes": the explicit form for a line in another format
  let nl = country.nl()
  assert.eq((nl.parse-city)("1012 Amsterdam").post-code, none)
  assert.eq((nl.parse-city)((name: "Amsterdam", post-code: "1012 AB")), (
    name: "Amsterdam",
    post-code: "1012 AB",
  ))
})[
  #line-items[#item([Consulting], price: 100)]
]
