#import "prelude.typ": *
// A company-specific window: geometry lives in a derived layout, not in patches
#let our-window = theme.layout.derive(theme.layout.din-5008-a, {
  import theme.custom: *
  area("address", left: 24mm, top: 40mm)
  area("info", top: 45mm)
  page(margin: (bottom: 35mm))
})
#show: invoice.with(
  locale: locale.de-de,
  ..party,
  theme: theme.classic.with(layout: our-window),
)
#body()
