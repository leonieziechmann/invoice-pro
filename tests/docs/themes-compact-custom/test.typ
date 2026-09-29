// Source: docs/docs/themes/compact.md — "Make It Yours"
#import "/tests/docs/prelude.typ": *

#show: invoice.with(
  theme: theme.compact.with({
    import theme.custom: *
    brand(
      color: rgb("#14532d"), // table header, stripes and totals
      logo: image("logo.svg", alt: "Atelier Nord GmbH"),
    )
    sizes(body: 9pt) // a little larger than the default 8.5 pt
  }),
  ..party,
)
#body()
