// Preset validation harness (scripts/checks-presets-business.sh): one preset on one
// layout with a seed colour, WCAG AA contrast checks (core pairs + the preset's
// checks.pairs) and an optional image logo with alt text (PDF/UA-1).
//   --input look=<preset>  --input layout=<name>|auto  --input color=<hex>|none
//   --input n=<items>  --input logo=box|image  --input zugferd=1  --input tint=<hex>
#import "/tests/body.typ": *
#let look = sys.inputs.at("look", default: "corporate")
#let lay = sys.inputs.at("layout", default: "auto")
#let seed = sys.inputs.at("color", default: "none")
#let img = sys.inputs.at("logo", default: "box") == "image"
#let patches = (
  theme.custom.checks(min-contrast: 4.5),
  theme.custom.logo(image: if img {
    image("/tests/gallery/vossberg.svg", alt: "Atelier Nord GmbH")
  } else { logo-img }),
  if seed != "none" { theme.custom.colors(primary: rgb(seed)) },
  // negative check: a dark tint must fail the preset's own pairs
  if "tint" in sys.inputs { theme.custom.colors(tint: rgb(sys.inputs.tint)) },
)
#let th = dictionary(theme).at(look).with(..patches.filter(p => p != none))
#show: invoice.with(
  theme: if lay == "auto" { th } else {
    th.with(layout: dictionary(theme.layout).at(lay))
  },
  locale: test-locale,
  ..party,
  zugferd: if sys.inputs.at("zugferd", default: "") != "" { "basic" },
)
#body(n: int(sys.inputs.at("n", default: "4")))
