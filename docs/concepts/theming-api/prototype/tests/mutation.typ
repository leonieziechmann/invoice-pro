// Token mutation test (concept §3.2 rule "frozen only if a built-in reads it"):
// `--input tok=group.key` sets one token to an extreme value; scripts/mutation.sh
// asserts that the render differs from the unmutated one under ANY of its LOOKS
// (a preset name, or rail).
#import "/tests/body.typ": *
#let tok = sys.inputs.at("tok", default: "")
#let look = sys.inputs.at("look", default: "classic")
#let extreme = (
  colors: rgb("#ff00ff"),
  fonts: "DejaVu Sans Mono",
  sizes: 15pt,
  weights: "light",
  strokes: 3pt,
  spacing: 2em,
  radii: 12pt,
)
#let patch = if tok == "" { () } else {
  let (g, k) = tok.split(".")
  let v = if tok == "fonts.number-width" { "proportional" } else if (
    tok == "sizes.fine"
  ) { 9pt } else { extreme.at(g) }
  ((tokens: ((g): ((k): v))),)
}
#show: invoice.with(
  theme: (
    if look == "rail" { theme.classic } else { dictionary(theme).at(look) }
  ).with(
    patch,
    theme.custom.logo(image: logo-img),
    // rail: a dark letterhead, so the logo sits on its light plate
    if look == "rail" {
      theme.custom.area("letterhead", fill: rgb("#1c1a17"), text: (fill: white))
    },
    // number-width needs a font with both figure styles (Liberation Sans has tabular digits only)
    if sys.inputs.at("font", default: none) != none {
      theme.custom.fonts(body: sys.inputs.font)
    },
  ),
  locale: test-locale,
  ..party,
)
#body(n: 8)
