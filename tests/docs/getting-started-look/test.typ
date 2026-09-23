// Source: docs/docs/getting-started.md — "Choosing a Look"
#import "/tests/docs/prelude.typ": *

#show: invoice.with(
  theme: theme.elegant.with(theme.custom.brand(color: rgb("#1c2a48"))),
  ..party,
)
#body()
