#import "prelude.typ": *
#show: invoice.with(locale: locale.de-de, ..party, theme: theme.corporate(
  layout: theme.layout.din-5008-b,
  {
    import theme.custom: *
    brand(
      color: rgb("#111827"),
      accent: rgb("#6366f1"),
      font: ("Inter", "Libertinus Serif"),
      heading-font: ("Fraunces", "Libertinus Serif"),
      logo: image("logo.svg", alt: "Atelier Nord"),
    )
    area("letterhead", parts: ("sender", "logo")) // logo right: data, no renderer
    totals(width: 100%, fill: none)
    wrap("totals", (ctx, view, inner) => block(
      stroke: (left: 3pt + ctx.theme.tokens.colors.accent),
      inset: (left: 6pt),
      inner(ctx, view),
    ))
    part("payment-terms", (ctx, view) => {
      let amount = (ctx.locale.format.currency)(view.total)
      let fill = ctx.theme.tokens.colors.accent.lighten(88%)
      let due = [Fällig in #view.days Tagen: *#amount*]
      block(fill: fill, inset: 1em, text(size: 1.2em, due))
    })
  },
))
#body()
