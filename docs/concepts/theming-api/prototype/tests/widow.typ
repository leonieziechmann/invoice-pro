// Totals never start a page alone: the built-in table keeps its last entry with
// the totals (line-items composite -> view.tail). Asserts that the last item and
// the totals land on the same page for row counts around every page boundary.
//   --input look=<preset>  --input layout=<name>|auto  --input n=<items>  [--input group=1]
#import "/tests/body.typ": *
#let look = sys.inputs.at("look", default: "classic")
#let lay = sys.inputs.at("layout", default: "din-5008-a")
#let n = int(sys.inputs.at("n", default: "18"))
#let grouped = sys.inputs.at("group", default: "0") == "1"
#let probe = theme.custom.wrap("totals", (ctx, view, inner) => [#metadata(
    "totals",
  )<w-totals>#inner(ctx, view)])
#show: invoice.with(
  theme: dictionary(theme)
    .at(look)
    .with(probe, ..if lay != "auto" {
      (layout: dictionary(theme.layout).at(lay))
    }),
  locale: test-locale,
  ..party,
)
#line-items[
  #let items = range(n).map(i => item(
    [Position #(i + 1)#if i == n - 1 [#metadata("last")<w-last>]],
    price: 100 + i,
  ))
  #if grouped { group([Group])[#items.join()] } else { items.join() }
]
#payment-terms(days: 14)
#context {
  let last = locate(<w-last>).page()
  let tot = query(<w-totals>)
  assert(
    tot.len() == 1,
    message: "totals rendered " + str(tot.len()) + " times",
  )
  assert(
    tot.first().location().page() == last,
    message: "widowed totals: last item on page "
      + str(last)
      + ", totals on page "
      + str(tot.first().location().page()),
  )
}
