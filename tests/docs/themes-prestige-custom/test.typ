// Source: docs/docs/themes/prestige.md — "Make It Yours"
#import "/tests/docs/prelude.typ": *

#show: invoice.with(
  theme: theme.prestige.with(
    theme.custom.brand(
      color: rgb("#12372a"), // the band
      accent: rgb("#d4b483"), // the type on the band and the rules on the page
    ),
    theme.custom.logo(
      image: image("logo.svg", alt: "Atelier Nord GmbH"),
      // a light variant for the dark band; without it the logo gets a light plate
      on-dark: image("logo-light.svg", alt: "Atelier Nord GmbH"),
    ),
  ),
  ..party,
)
#body()
