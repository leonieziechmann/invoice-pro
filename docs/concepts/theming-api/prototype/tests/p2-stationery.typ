// P2: GmbH, one switch for pre-printed / digital letterhead / e-invoice.
#import "/tests/body.typ": *
#let mode = sys.inputs.at("output", default: "pdf") // print | pdf | einvoice
#let acme = {
  import theme.custom: *
  brand(color: rgb("#003a70"), accent: rgb("#e2001a"), logo: image(
    "/tests/lh1.svg",
    height: 10mm,
    alt: "ACME Maschinenbau GmbH",
  ))
}
#show: invoice.with(
  theme: theme.classic.with(acme, layout: theme.layout.din-5008-b, {
    import theme.custom: *
    stationery(if mode == "print" { "pre-printed" } else if mode == "pdf" {
      (first: image("/tests/lh1.svg"), rest: image("/tests/lh2.svg"))
    } else { none })
    if mode != "print" { marks(none) }
    if mode == "pdf" { area("continuation", none) } // the rest-page art has its own header
  }),
  locale: test-locale,
  zugferd: if mode == "einvoice" { "basic" },
  ..party,
)
#body(n: 22)
