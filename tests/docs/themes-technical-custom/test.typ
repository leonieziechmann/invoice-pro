// Source: docs/docs/themes/technical.md — "Make It Yours"
#import "/tests/docs/prelude.typ": *

#show: invoice.with(
  theme: theme.technical.with({
    import theme.custom: *
    brand(
      color: rgb("#6d28d9"),
      logo: image("logo.svg", alt: "Atelier Nord GmbH"),
    )
    // labels and figures in your own monospace font, the embedded one as fallback
    fonts(
      label: ("JetBrains Mono", "DejaVu Sans Mono"),
      numeric: ("JetBrains Mono", "DejaVu Sans Mono"),
    )
  }),
  ..party,
)
#body()
