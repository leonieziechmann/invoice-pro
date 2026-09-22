#import "prelude.typ": *
#show: invoice.with(locale: locale.de-de, ..party, theme: theme.classic.with({
  import theme.custom: *
  part("signature", (ctx, view) => [— #view.name]) // replace
  wrap("bank-details", (ctx, view, inner) => block(
    fill: ctx.theme.tokens.colors.tint,
    inset: 8pt,
    inner(ctx, view),
  )) // wrap
  part("totals", (ctx, view) => {
    // eject: start from the default renderer, then edit
    set text(fill: ctx.theme.tokens.colors.primary)
    theme.parts.totals(ctx, view)
  })
}))
#body()
