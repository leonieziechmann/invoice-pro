// The findings of the layout under the default of a hydrated invoice: a
// footer taller than the bottom margin leaves (lint/footer-fit), a title
// without the number and the date (theme/identity-*), a scope with too little
// contrast (themed/..) and a totals part that renders nothing
// (theme/empty-totals). The strict stop comes after the layout and lists them
// with the data's problems; the draft flag marks them.
#import "/repo/src/lib.typ": *
#let tall = [#for i in range(14) [Line #i #linebreak()]]
#show: invoice.with(
  data: data.load(read: p => read(p, encoding: none)),
  theme: theme.classic.with(
    theme.custom.page(margin: (bottom: 32mm)),
    theme.custom.area("footer", parts: (tall,)),
    theme.custom.part("title", (ctx, view) => [Dear customer]),
    theme.custom.part("totals", (ctx, view) => []),
  ),
  locale: locale.de-de,
  zugferd: "en16931",
  sender: (
    name: "ACME GmbH",
    address: "Weg 1",
    city: "80331 München",
    country: "DE",
    vat-id: "DE123456789",
  ),
  recipient: (name: "Muster", address: "Musterweg 1", city: "10115 Berlin"),
  invoice-nr: "MUSTER-0001",
)
#themed(
  theme.custom.checks(min-contrast: 4.5),
  theme.custom.colors(text-muted: rgb("#f472b6")),
)[#line-items[#item("Muster", price: 1)]]
#payment(
  terms: (days: 14),
  bank: (iban: "DE75512108001245126199"),
  creditor-id: "DE98ZZZ09999999999",
)
