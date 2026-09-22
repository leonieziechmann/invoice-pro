#import "prelude.typ": *
#let mode = sys.inputs.at("output", default: "pdf") // print | pdf | einvoice
#let acme = theme.custom.brand(
  color: rgb("#003a70"),
  accent: rgb("#e2001a"),
  font: ("Source Sans 3", "Liberation Sans", "Libertinus Serif"),
  logo: image("acme.svg", alt: "ACME Maschinenbau GmbH"),
)
#show: invoice.with(
  theme: theme.classic.with(acme, layout: theme.layout.din-5008-b, {
    import theme.custom: *
    if mode == "print" { stationery("pre-printed") }
    if mode == "pdf" {
      stationery((first: image("lh-1.svg"), rest: image("lh-2.svg")))
      area("continuation", none) // the rest-page art carries its own header
    }
    if mode != "print" { marks(none) }
  }),
  locale: locale.de-de,
  ..party,
  zugferd: if mode == "einvoice" { "basic" },
)
#body(n: int(sys.inputs.at("n", default: "4")))
