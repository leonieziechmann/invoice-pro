// Source: README.md — "Theming"
#import "/tests/docs/prelude.typ": *

#show: invoice.with(
  theme: theme.elegant.with(theme.custom.brand(
    color: rgb("#0f766e"),
    logo: image("logo.svg", alt: "Your Company"),
  )),
  ..party,
)
#body()
