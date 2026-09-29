// Source: docs/docs/themes/index.md — "Your Brand on Any Theme"
#import "/tests/docs/prelude.typ": *

#let brand = theme.custom.brand(
  color: rgb("#0f766e"),
  logo: image("logo.svg", alt: "Atelier Nord GmbH"),
)

#show: invoice.with(
  theme: theme.soft.with(brand), // or theme.classic.with(brand), theme.bold.with(brand), ..
  ..party,
)
#body()
