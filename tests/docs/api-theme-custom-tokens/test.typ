// Source: docs/docs/api-reference/theme/customization.md — "Tokens"
#import "/tests/docs/prelude.typ": *

#show: invoice.with(
  theme: theme.classic.with({
    import theme.custom: *
    colors(
      primary: rgb("#7c2d12"),
      tint: t => t.colors.primary.lighten(92%), // stripes follow the brand color
      border: t => t.colors.primary,
    )
    sizes(body: 9.5pt, title: 1.6em)
    strokes(thick: 1.2pt)
  }),
  ..party,
)
#body()
