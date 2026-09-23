// Source: docs/docs/api-reference/theme/layouts.md — "Layout by Region"
#import "/src/lib.typ": *

// layout: auto (the default) follows the sender: an Austrian sender gets din-5008-b
#show: invoice.with(
  locale: locale.de-at,
  sender: (
    name: "Kaffeehaus Weber GmbH",
    address: "Kärntner Ring 5",
    city: "1010 Wien",
    country: country.at,
    vat-id: "ATU12345678",
  ),
  recipient: (
    name: "Muster AG",
    address: "Beispielweg 5",
    city: "1020 Wien",
  ),
  invoice-nr: "2026-0142",
  theme: theme.classic, // pin a page master with theme.classic.with(layout: ..)
)

#line-items[
  #item([Catering, 40 guests], price: 1200)
]

// the Austrian sender resolves to DIN 5008 form B
#let env = (kind: "invoice", lang: "de", region: "at", e-invoice: none)
#assert.eq(theme.resolve(theme.classic, env: env).layout.name, "din-5008-b")
