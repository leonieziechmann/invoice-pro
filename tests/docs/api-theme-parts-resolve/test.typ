// Source: docs/docs/api-reference/theme/parts.md — "Testing a Theme: theme.resolve"
#import "/tests/docs/prelude.typ": *

#let company = theme.classic.with(
  theme.custom.brand(color: rgb("#0f766e")),
  theme.custom.checks(min-contrast: 4.5),
)

#let t = theme.resolve(company)
#assert.eq(t.tokens.colors.primary, rgb("#0f766e"))
#assert.eq(t.layout.name, "din-5008-a")
#assert.eq(t.issues, ())

#let us = theme.resolve(company, env: (
  kind: "invoice",
  lang: "en",
  region: "us",
  e-invoice: none,
))
#assert.eq(us.layout.name, "us-letter-10")

#show: invoice.with(theme: company, ..party)
#body()
