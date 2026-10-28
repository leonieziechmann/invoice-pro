// Source: docs/docs/api-reference/theme/index.md — "Passing a Theme"
#import "/tests/docs/prelude.typ": *

#let a = theme.classic // the default
#let b = theme.classic.with(layout: theme.layout.din-5008-b) // another page master
#let c = theme.corporate.with(theme.custom.brand(color: rgb("#003a70"))) // a brand is a patch
#let d = theme.elegant(layout: theme.layout.a4-digital) // calling it is the same as .with

#show: invoice.with(theme: b, ..party)
#body()

// every form resolves
#for th in (a, c, d) { let _ = theme.resolve(th) }
