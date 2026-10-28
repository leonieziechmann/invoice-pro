// Source: docs/docs/api-reference/invoice/index.md — "theme"
#import "/tests/docs/prelude.typ": *

#show: invoice.with(
  theme: theme.classic.with(
    theme.custom.brand(color: rgb("#0f766e")),
    layout: theme.layout.din-5008-b,
  ),
  ..party,
)
#body()
