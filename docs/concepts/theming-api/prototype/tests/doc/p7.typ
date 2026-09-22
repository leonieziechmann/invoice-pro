#import "prelude.typ": *
#let logo = image("sw.svg", alt: "Stadtwerke Musterstadt")
#show: invoice.with(locale: locale.de-de, ..party, theme: theme.classic.with(
  theme.custom.brand(color: rgb("#00843d"), logo: logo),
  theme.custom.checks(min-contrast: 4.5),
  theme.custom.marks(none),
))
#body()
