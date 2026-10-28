// Source: docs/docs/api-reference/theme/parts.md — "The Part Contract"
#import "/tests/docs/prelude.typ": *

#show: invoice.with(
  theme: theme.classic.with({
    import theme.custom: *
    part("signature", (ctx, view) => [— #view.name]) // replace
    wrap("bank-details", (ctx, view, inner) => block(
      fill: ctx.theme.tokens.colors.tint,
      inset: 8pt,
      inner(ctx, view),
    )) // wrap
    part("totals", (ctx, view) => {
      // eject: start from the built-in renderer, then change it
      set text(fill: ctx.theme.tokens.colors.primary)
      theme.parts.totals(ctx, view)
    })
  }),
  ..party,
)
#body()
