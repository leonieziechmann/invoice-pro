#import "prelude.typ": *
#show: invoice.with(locale: locale.de-de, ..party)
#line-items[
  #group([Phase 1])[#item([Konzeption], price: 1800)]
  #themed(theme.custom.row(fill: rgb("#fef3c7")))[
    #group([Phase 2 (optional)])[
      #item([Reinzeichnung], price: 650)
      #item([Druck], price: 240)
    ]
  ]
]
#themed({
  import theme.custom: *
  colors(primary: rgb("#b91c1c")) // tint re-derives inside the scope
  wrap("bank-details", (ctx, view, inner) => block(
    fill: ctx.theme.tokens.colors.tint,
    inset: 8pt,
    inner(ctx, view),
  ))
})[#bank-details(bank: "Hamburger Sparkasse", iban: "DE75512108001245126199")]
