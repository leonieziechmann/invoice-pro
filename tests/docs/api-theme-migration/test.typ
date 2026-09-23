// Source: docs/docs/api-reference/theme/migration.md — "Before and After (0.5)"
// The payment-terms call of the block is part of body().
#import "/tests/docs/prelude.typ": *

// 0.5
#show: invoice.with(
  theme: theme.classic.with(
    layout: theme.layout.din-5008-b,
    theme.custom.fonts(body: ("Inter", "Liberation Sans", "Libertinus Serif")),
    theme.custom.marks(punch: none),
  ),
  ..party,
)
#body()
