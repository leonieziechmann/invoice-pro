// The widow sweep (prototype tests/widow.typ, scripts/checks-presets*.sh):
// totals never start a page alone. The built-in table keeps its last entry with
// the totals (line-items composite -> view.tail), so the last item and the
// totals land on the same page, for row counts around the first page boundary
// (14..22 items), with and without a closing group subtotal.
#import "/tests/theme/body.typ": *
#import "/tests/theme/harness.typ": case, close-cases, span-of

// one probe for every case: equal patches keep the theme resolution cached
#let probe = theme.custom.wrap("totals", (ctx, view, inner) => [#metadata(
    "totals",
  )<widow-totals>#inner(ctx, view)])

#let key-of(look, lay, n, grouped) = (
  look + "/" + lay + "/" + str(n) + (if grouped { "/group" } else { "" })
)

/// Renders the sweep for every (look, layout) pair and asserts the widow rule.
/// -> content
#let widow-sweep(pairs, sweep: range(14, 23)) = {
  let keys = ()
  for (look, lay) in pairs {
    for n in sweep {
      for grouped in (false, true) {
        let key = key-of(look, lay, n, grouped)
        keys.push(key)
        case(
          key,
          theme: preset-of(look).with(probe, layout: layout-of(lay)),
          locale: test-locale,
          ..party,
          [
            #line-items[
              #let items = range(n).map(i => item(
                [Position #(i + 1)#if i == n - 1 [#metadata(key)<widow-last>]],
                price: 100 + i,
              ))
              #if grouped { group([Group])[#items.join()] } else {
                items.join()
              }
            ]
            #payment-terms(days: 14)
          ],
        )
      }
    }
  }
  close-cases()
  context {
    let lasts = query(<widow-last>)
    let totals = query(<widow-totals>)
    for key in keys {
      let s = span-of(key)
      let last = lasts.filter(m => m.value == key)
      let tot = totals.filter(m => {
        let p = m.location().page()
        p >= s.first and p < s.first + s.pages
      })
      assert(last.len() == 1, message: key + ": last item not rendered once")
      assert(
        tot.len() == 1,
        message: key + ": totals rendered " + str(tot.len()) + " times",
      )
      assert(
        tot.first().location().page() == last.first().location().page(),
        message: key
          + ": widowed totals: last item on page "
          + str(last.first().location().page() - s.first + 1)
          + ", totals on page "
          + str(tot.first().location().page() - s.first + 1),
      )
    }
  }
}
