// Source: docs/docs/themes/classic.md — "Make It Yours"
#import "/tests/docs/prelude.typ": *

#show: invoice.with(
  theme: theme.classic.with(
    theme.custom.brand(
      color: rgb("#0f766e"), // table stripes and text colors derive from it
      logo: image("logo.svg", alt: "Atelier Nord GmbH"),
    ),
    theme.custom.marks(punch: none), // fold marks only
    layout: theme.layout.din-5008-b, // the taller letterhead zone of form B
  ),
  ..party,
)
#body()
