// Render pairs for scripts/checks-api-frame.sh: each case is compiled in variant
// a and b; the script asserts that the two renders differ (or are identical).
//   --input case=<name> --input v=a|b
#import "/tests/body.typ": *
#import theme.custom: *
#let case = sys.inputs.at("case")
#let v = sys.inputs.at("v", default: "a")
#let ab(a, b) = if v == "a" { a } else { b }
#let dark = area("letterhead", fill: rgb("#1c1a17"), text: (fill: white))
#let light = area("letterhead", fill: rgb("#f4f1ea"))
#let patch = (
  // legal footer parts inherit the area's text colour (differ)
  legal-fill: area("footer", text: (fill: ab(rgb("#b91c1c"), rgb("#1d4ed8")))),
  // on a dark letterhead the logo gets a plate unless on-dark is none (differ)
  logo-dark: (dark, logo(on-dark: ab(auto, none))),
  // on a light letterhead on-dark has no effect (identical)
  logo-light: (light, logo(on-dark: ab(auto, none))),
  // a replacement logo for dark surfaces (differ)
  logo-alt: (
    dark,
    logo(on-dark: ab(auto, box(width: 30mm, height: 10mm, stroke: white))),
  ),
  // rows honour gap (differ)
  rows-gap: area("address", gap: ab(0pt, 4mm)),
  // look-safe cell-align, par, radius, rule (differ)
  cell-align: area("letterhead", cell-align: ab(auto, (
    right + top,
    left + bottom,
  ))),
  par: area("letterhead", par: ab((:), (leading: 1.2em))),
  radius: (
    area("address", fill: luma(230)),
    area("address", radius: ab(0pt, 3mm)),
  ),
  rule: area("title", rule: ab(none, (
    side: bottom,
    gap: 2mm,
    stroke: 1pt + red,
  ))),
  // the rule is zero-height: it moves nothing, so a rule drawn in white on white
  // renders exactly like no rule (identical)
  rule-height: area("footer", rule: ab(none, (
    side: top,
    gap: 1mm,
    stroke: 0.5pt + white,
  ))),
  // page-number from: auto shows "Page 1 of 2" on page 1; from: 2 does not (differ on page 1)
  page-from: page-number(from: ab(auto, 2)),
).at(case)
#show: invoice.with(
  theme: theme.classic.with(
    brand(logo: logo-img),
    patch,
    layout: theme.layout.din-5008-a,
  ),
  locale: test-locale,
  ..party,
)
#body(n: if case == "page-from" { 30 } else { 4 })
