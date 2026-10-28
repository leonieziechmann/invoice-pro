// Source: docs/docs/themes/soft.md — "Make It Yours"
#import "/tests/docs/prelude.typ": *

#show: invoice.with(
  theme: theme.soft.with({
    import theme.custom: *
    brand(
      color: rgb("#2f6f5e"), // the pastel cards and the pills follow the brand color
      logo: image("logo.svg", alt: "Atelier Nord GmbH"),
    )
    radii(small: 3pt, medium: 6pt) // less rounded cards
  }),
  ..party,
)
#body()
