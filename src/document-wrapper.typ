#import "loom-wrapper.typ": *
#import "data/tax.typ" as m-tax

#let date(d, m, y) = datetime(day: d, month: m, year: y)

#let format-currency(number, locale: "en", precision: 2, fallback: 2) = {
  assert(precision > 0)
  assert(fallback > 0)

  if (
    calc.round(digits: precision, number)
      != calc.round(digits: fallback, number)
  ) {
    precision = fallback
  }

  let s = str(calc.round(number, digits: precision))
  let after_dot = s.find(regex("\..*"))
  if after_dot == none {
    s = s + "."
    after_dot = "."
  }
  for i in range(precision - after_dot.len() + 1) {
    s = s + "0"
  }
  // fake de locale
  if locale == "de" {
    s.replace(".", ",")
  } else {
    s
  }
}


#let invoice(
  tax: m-tax.vat(19%),
) = body => {
  set page("a4")
  weave(max-passes: 2, managed-motif(
    "document-root",
    scope: ctx => loom.mutator.batch(ctx, {
      import loom.mutator: *

      put("tax", tax)
      put("unit", [Stk.])

      nest("format", {
        put("date", date => {
          if type(date) == datetime {
            date.display("[day].[month].[year]")
          } else if type(date) == array {
            let start = date.first().display("[day].[month].[year]")
            let end = date.last().display("[day].[month].[year]")
            (start, " - ", end).join()
          }
        })
        put("currency", x => [#format-currency(x)€])
        put(
          "currency-fine",
          x => [#format-currency(precision: 2, fallback: 4, x)€],
        )
      })
    }),
    body,
  ))
}
