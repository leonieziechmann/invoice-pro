#import "prelude.typ": *
#import "@local/acme-theme:0.1.0" as acme
#let acme-brand = theme.custom.brand(color: rgb("#003a70"))
#let a = theme.classic                                           // the default
#let b = theme.classic.with(layout: theme.layout.us-letter-digital) // another page master
#let c = theme.corporate.with(acme-brand)                           // a brand is a patch array
#let d = theme.classic.with(acme.patch, layout: acme.sidebar-a5) // a zero-import package
#show: invoice.with(theme: d, locale: locale.de-de, ..party)
#body()
#for th in (a, b, c) { let _ = theme.resolve(th) }
