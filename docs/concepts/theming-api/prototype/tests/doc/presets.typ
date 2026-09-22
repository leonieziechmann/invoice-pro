#import "prelude.typ": *
#let pick = sys.inputs.at("preset", default: "elegant") // any of the ten presets
#let brand = theme.custom.brand(
  color: rgb("#0f766e"),
  logo: image("logo.svg", alt: "Atelier Nord"),
)
#show: invoice.with(
  locale: locale.de-de,
  ..party,
  theme: dictionary(theme).at(pick).with(brand),
)
#body()
