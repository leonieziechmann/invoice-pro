// Source: docs/docs/themes/elegant.md — "Make It Yours"
#import "/tests/docs/prelude.typ": *

#show: invoice.with(
  theme: theme.elegant.with(
    theme.custom.brand(
      color: rgb("#5b1f2e"), // one ink color: letterhead, key labels, the payable
      heading-font: ("Cormorant Garamond", "Libertinus Serif"),
      logo: image("logo.svg", alt: "Atelier Nord GmbH"),
    ),
  ),
  ..party,
)
#body()
