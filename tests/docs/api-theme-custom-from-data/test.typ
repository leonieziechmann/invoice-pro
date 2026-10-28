// Source: docs/docs/api-reference/theme/customization.md — "Brand Files: from-data"
#import "/tests/docs/prelude.typ": *

#let brand = toml("brand.toml")

#show: invoice.with(
  theme: theme.corporate.with(theme.custom.from-data(
    brand.theme,
    assets: path => image(path, alt: "Nordlicht Studio"),
  )),
  ..party,
)
#body()
