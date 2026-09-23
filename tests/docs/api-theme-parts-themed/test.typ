// Source: docs/docs/api-reference/theme/parts.md — "Scoped Overrides: themed"
#import "/tests/docs/prelude.typ": *

#show: invoice.with(locale: locale.en-de, ..party)

#line-items[
  #group([Phase 1])[#item([Concept], price: 1800)]
  #themed(theme.custom.row(fill: rgb("#fef3c7")))[
    #group([Phase 2 (optional)])[
      #item([Artwork], price: 650)
      #item([Print], price: 240)
    ]
  ]
]

#themed({
  import theme.custom: *
  colors(primary: rgb("#b91c1c")) // the tint re-derives inside the scope
  wrap("bank-details", (ctx, view, inner) => block(
    fill: ctx.theme.tokens.colors.tint,
    inset: 8pt,
    inner(ctx, view),
  ))
})[#bank-details(bank: "Hamburger Sparkasse", iban: "DE75512108001245126199")]
