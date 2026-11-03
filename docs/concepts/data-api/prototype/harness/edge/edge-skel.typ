// Skeleton of the edge invoice (engine judge's edge-hand.typ): samples, then
// hydrated by --input invoice-pro-data-file=<json>.
// --input wrap=1: static rows around `apply(..)[#invoice-data.items[..]]`
// (the explicit marker inside an `apply`); --input marker=1: static rows and
// the marker without `apply`; otherwise the implicit slot.
#import "/repo/src/lib.typ": *
#import "common.typ": *
#let wrap = sys.inputs.at("wrap", default: "0") == "1"
#let marker = sys.inputs.at("marker", default: "0") == "1"
#show: invoice.with(
  data: invoice-data.load(read: p => read(p, encoding: none)),
  zugferd: zugf,
  sender: sender,
  recipient: (name: "Sample"),
  invoice-nr: "S",
  tax: tax.vat(19%),
)
#let sample = [#item("Sample", price: 1)]
#line-items(tax: 19%)[
  #if wrap [
    #item("Statisch vorher", price: 3)
    #apply(description: "Kaskade")[#invoice-data.items(sample)]
    #item("Statisch nachher", price: 4)
  ] else if marker [
    #item("Statisch vorher", price: 3)
    #invoice-data.items(sample)
    #item("Statisch nachher", price: 4)
  ] else { sample }
]
#payment(terms: (days: 14))
