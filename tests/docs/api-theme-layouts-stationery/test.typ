// Source: docs/docs/api-reference/theme/layouts.md — "Stationery"
#import "/tests/docs/prelude.typ": *

#let mode = sys.inputs.at("output", default: "pdf") // print | pdf | einvoice

#show: invoice.with(
  theme: theme.classic.with(layout: theme.layout.din-5008-b, {
    import theme.custom: *
    if mode == "print" { stationery("pre-printed") }
    if mode == "pdf" {
      stationery((
        first: image("letterhead-1.svg"),
        rest: image("letterhead-2.svg"),
      ))
      area("continuation", none) // the art of following pages has its own header
    }
    if mode != "print" { marks(none) }
  }),
  zugferd: if mode == "einvoice" { "basic" },
  ..party,
)
#body()
