// Source: docs/docs/api-reference/theme/parts.md — "Theme Packages"
// The package is the local file acme-theme.typ instead of @preview/acme-theme.
#import "/src/lib.typ": *
#import "/tests/docs/prelude.typ": body, party
#import "acme-theme.typ" as acme

#show: invoice.with(
  theme: theme.classic.with(acme.patch, layout: acme.sidebar-a5),
  ..party,
)
#body()

// package CI
#let _ = theme.resolve(theme.classic.with(acme.patch, layout: acme.sidebar-a5))
