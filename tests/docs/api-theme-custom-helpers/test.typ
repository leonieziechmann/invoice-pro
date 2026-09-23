// Source: docs/docs/api-reference/theme/customization.md — "Patches and Helpers"
#import "/tests/docs/prelude.typ": *

#show: invoice.with(
  theme: theme.classic.with({
    import theme.custom: *
    colors(primary: rgb("#1d4ed8"), accent: rgb("#15803d"))
    fonts(body: ("Inter", "Liberation Sans", "Libertinus Serif"))
    items-table(zebra: (none, none))
    totals(fill: rgb("#1d4ed8"))
  }),
  ..party,
)
#body()
