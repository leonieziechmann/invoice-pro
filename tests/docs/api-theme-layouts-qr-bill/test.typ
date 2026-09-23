// Source: docs/docs/api-reference/theme/layouts.md — "Swiss QR-Bill Zone (0.5.x Preview)"
// Test variant: the QR-bill zone is on by default (tytanic cannot pass --input).
#import "/tests/docs/prelude.typ": *

#let sn = theme.layout.sn-010130-right // what layout: auto picks for a Swiss sender
#let qr-bill = sys.inputs.at("qr-bill", default: "1") == "1" // opt-in preview

#show: invoice.with(
  locale: locale.de-ch,
  theme: theme.classic.with(
    layout: if qr-bill { theme.layout.reserve-qr-bill(sn) } else { sn },
    {
      import theme.custom: *
      if sys.inputs.at("window", default: "right") == "left" {
        area("address", left: 22mm) // setting left clears right
        area("info", right: 18mm) // setting right clears left
      }
    },
  ),
  ..party,
  sender: party.sender + (city: "8001 Zürich", country: country.ch),
)
#body()
