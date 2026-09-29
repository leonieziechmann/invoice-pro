// Source: docs/docs/themes/boxed.md — "Make It Yours"
#import "/tests/docs/prelude.typ": *

#show: invoice.with(
  theme: theme.boxed.with(
    theme.custom.brand(
      color: rgb("#1d4ed8"), // only the letterhead rule: no color carries meaning
      logo: image("logo.svg", alt: "Atelier Nord GmbH"),
    ),
  ),
  ..party,
)
#body()
