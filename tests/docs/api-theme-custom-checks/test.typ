// Source: docs/docs/api-reference/theme/customization.md — "Checks"
#import "/tests/docs/prelude.typ": *

#show: invoice.with(
  theme: theme.classic.with(
    theme.custom.brand(color: rgb("#facc15")), // a light brand color
    theme.custom.checks(
      min-contrast: 4.5,
      pairs: (stamp: t => (t.colors.accent-text, t.colors.background)),
    ),
  ),
  ..party,
)
#body()
