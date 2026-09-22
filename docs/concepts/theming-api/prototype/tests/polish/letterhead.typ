// prestige/elegant letterheads under stress (scripts/checks-fix-polish.sh):
// a long sender name, a wide or a tall logo on the on-dark plate, any layout.
//   --input look=prestige|elegant  --input layout=<name>|auto
//   --input name=short|long  --input logo=wide|tall|light|none
#import "/tests/body.typ": *
#let look = sys.inputs.at("look", default: "prestige")
#let lay = sys.inputs.at("layout", default: "sn-010130-right")
#let long = sys.inputs.at("name", default: "long") == "long"
#let kind = sys.inputs.at("logo", default: "wide")
#let tall-mark = box(
  width: 14mm,
  height: 14mm,
  fill: rgb("#1c1a17"),
  radius: 2pt,
  align(
    center + horizon,
    text(fill: white, weight: "bold", size: 12pt)[HB],
  ),
)
#let logo = if kind == "wide" {
  theme.custom.logo(image: logo-img)
} else if kind == "tall" {
  theme.custom.logo(image: tall-mark, height: 18mm)
} else if kind == "light" {
  theme.custom.logo(image: logo-img, on-dark: text(fill: white)[ATELIER·NORD])
} else { theme.custom.logo(image: none) }
#show: invoice.with(
  theme: dictionary(theme)
    .at(look)
    .with(logo, layout: if lay == "auto" { auto } else {
      dictionary(theme.layout).at(lay)
    }),
  locale: test-locale,
  ..party,
  sender: party.sender
    + if long { (name: "Grand Hotel Bellevue Palace Bern AG") } else { (:) },
)
#body(n: 4)
