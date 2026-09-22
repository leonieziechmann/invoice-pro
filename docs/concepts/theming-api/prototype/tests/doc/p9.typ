#import "prelude.typ": *
#import "@local/acme-theme:0.1.0" as acme
#show: invoice.with(locale: locale.de-de, ..party, theme: theme.classic.with(
  acme.patch,
  layout: acme.sidebar-a5,
))
#body()
// package CI (against the published invoice-pro):
#let _ = theme.resolve(theme.classic.with(acme.patch, layout: acme.sidebar-a5))
