// Source: docs/docs/themes/corporate.md — "Make It Yours"
#import "/tests/docs/prelude.typ": *

#show: invoice.with(
  theme: theme.corporate.with(
    theme.custom.brand(
      color: rgb("#003a70"), // table header, payable bar, title, section labels
      accent: rgb("#e2001a"), // rules and ticks only, never text
      logo: image("logo.svg", alt: "Atelier Nord GmbH"),
    ),
  ),
  ..party,
)
#body()
