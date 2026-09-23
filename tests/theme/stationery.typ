// P2 (prototype tests/p2-stationery.typ): a GmbH with one switch for pre-printed
// paper, a digital letterhead or an e-invoice, on DIN 5008 B, 22 items.
#import "/tests/theme/body.typ": *

#let acme = {
  import theme.custom: *
  brand(color: rgb("#003a70"), accent: rgb("#e2001a"), logo: image(
    "/tests/theme/assets/lh1.svg",
    height: 10mm,
    alt: "ACME Maschinenbau GmbH",
  ))
}
/// mode: "print" | "pdf" | "einvoice"
#let stationery-invoice(mode) = invoice(
  theme: theme.classic.with(acme, layout: theme.layout.din-5008-b, {
    import theme.custom: *
    stationery(if mode == "print" { "pre-printed" } else if mode == "pdf" {
      (
        first: image("/tests/theme/assets/lh1.svg"),
        rest: image("/tests/theme/assets/lh2.svg"),
      )
    } else { none })
    if mode != "print" { marks(none) }
    if mode == "pdf" { area("continuation", none) } // the rest-page art has its own header
  }),
  locale: test-locale,
  zugferd: if mode == "einvoice" { "basic" },
  ..party,
  body(n: 22),
)
