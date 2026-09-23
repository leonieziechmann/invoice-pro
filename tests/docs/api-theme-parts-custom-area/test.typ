// Source: docs/docs/api-reference/theme/parts.md — "Custom Parts and Areas (a stamp)"
#import "/tests/docs/prelude.typ": *

#let paid(ctx, view) = {
  let accent = ctx.theme.tokens.colors.accent
  rotate(-12deg, block(
    stroke: 2pt + accent,
    inset: 6pt,
    radius: ctx.theme.tokens.radii.medium,
    text(size: 18pt, weight: "bold", fill: accent)[PAID],
  ))
}

#show: invoice.with(
  theme: theme.classic.with({
    import theme.custom: *
    part("acme/paid", paid)
    area(
      "stamp",
      place: "foreground",
      pages: "first",
      left: 140mm,
      top: 110mm,
      parts: ("acme/paid",),
    )
    colors(accent: rgb("#15803d"))
    checks(pairs: (paid-stamp: t => (t.colors.accent, t.colors.background)))
  }),
  ..party,
)
#body()
