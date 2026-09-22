#import "prelude.typ": *
#let sn = theme.layout.sn-010130-right // what layout: auto picks for a Swiss sender
#let qr-bill = sys.inputs.at("qr-bill", default: "") == "1" // opt-in, 0.5.x preview
#show: invoice.with(locale: locale.de-ch, ..party, theme: theme.classic.with(
  layout: if qr-bill { theme.layout.reserve-qr-bill(sn) } else { sn },
  {
    import theme.custom: *
    brand(color: rgb("#7a1f2b"), font: ("Source Serif 4", "Libertinus Serif"))
    if sys.inputs.at("window", default: "right") == "left" {
      area("address", left: 22mm) // setting left clears right
      area("info", right: 18mm) // setting right clears left
    }
  },
))
#body(n: int(sys.inputs.at("n", default: "4")))
