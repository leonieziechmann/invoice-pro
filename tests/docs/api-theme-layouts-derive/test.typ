// Source: docs/docs/api-reference/theme/layouts.md — "Deriving a Layout"
#import "/tests/docs/prelude.typ": *

// A company-specific window: geometry lives in a derived layout
#let our-window = theme.layout.derive(theme.layout.din-5008-a, {
  import theme.custom: *
  area("address", left: 24mm, top: 40mm)
  area("info", top: 45mm)
  page(margin: (bottom: 35mm))
})

#show: invoice.with(
  theme: theme.classic.with(layout: our-window),
  ..party,
)
#body()
