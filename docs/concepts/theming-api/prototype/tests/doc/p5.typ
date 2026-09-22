#import "prelude.typ": *
// theme.typ of the pipeline: built once, an immutable value imported everywhere
#let company = theme.classic.with(
  theme.custom.from-data(json("brand.json")),
  theme.custom.checks(min-contrast: 4.5),
)
#let locales = (de-de: locale.de-de, en-de: locale.en-de) // explicit map, no reflection
#let d = json("job.json")
#show: invoice.with(
  theme: company.with(layout: theme.layout.digital-for-region(d.region)),
  locale: locales.at(d.locale),
  ..party,
)
#body()
