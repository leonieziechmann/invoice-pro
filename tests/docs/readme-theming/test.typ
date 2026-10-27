// Source: README.md and .github/README.md — "Ten Looks, One Line"
#import "/tests/docs/prelude.typ": *

#show: invoice.with(
  theme: theme.bold.with(theme.custom.brand(
    color: rgb("#0f766e"),
    logo: image("logo.svg", alt: "Atelier Nord"),
  )),
  ..party,
)
#body()
