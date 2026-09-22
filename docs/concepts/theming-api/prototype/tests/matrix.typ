// Look x layout matrix: ONE body, any look on any layout (CI rule).
#import "/tests/body.typ": *
#import "/tests/looks.typ": minimal
#let look = sys.inputs.at("look", default: "classic")
#let lay = sys.inputs.at("layout", default: "din-5008-a")
// every preset of `theme` by name, plus the docs recipe `minimal`
#let preset = if look == "minimal" { minimal } else {
  dictionary(theme).at(look)
}
#let brand = theme.custom.brand(color: rgb("#0f766e"), logo: logo-img)
#show: invoice.with(
  // layout=auto: the preset picks its layout (by the sender region)
  theme: preset.with(brand, layout: if lay == "auto" { auto } else {
    dictionary(theme.layout).at(lay)
  }),
  locale: test-locale,
  ..party,
)
#body(n: int(sys.inputs.at("n", default: "4")))
