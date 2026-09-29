// Source: docs/docs/themes/bold.md — "Make It Yours"
#import "/tests/docs/prelude.typ": *

#show: invoice.with(
  theme: theme.bold.with(
    theme.custom.brand(
      color: rgb("#e4572e"), // the poster block, the stripes and the payable bar
      logo: image("logo.svg", alt: "Atelier Nord GmbH"),
    ),
  ),
  ..party,
)
#body()
