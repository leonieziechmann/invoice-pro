// Source: docs/docs/api-reference/theme/customization.md — "brand()"
#import "/tests/docs/prelude.typ": *

#let acme = theme.custom.brand(
  color: rgb("#003a70"),
  accent: rgb("#e2001a"),
  font: ("Source Sans 3", "Liberation Sans", "Libertinus Serif"),
  logo: image("logo.svg", alt: "ACME Maschinenbau GmbH"),
)

#show: invoice.with(
  theme: theme.classic.with(acme),
  ..party,
)
#body()
