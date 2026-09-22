#import "../loom-wrapper.typ": loom, managed-motif
#import "../utils/types.typ"
#import "../theming/parts/body.typ": call-part
#import "../utils/coercion.typ"

/// Displays the payment deadline and terms for the invoice.
///
/// -> content
#let payment-terms(
  /// The number of days allowed for payment from the invoice date.
  /// -> none | int
  days: none,

  /// A specific fixed date for the payment deadline.
  /// -> none | datetime | string | content
  date: none,
) = {
  types.require(days, "payment-terms::days", none, int)
  types.require(date, "payment-terms::date", none, datetime, str, content)

  managed-motif(
    "payment-terms",
    scope: ctx => loom.mutator.batch(ctx, {
      import loom.mutator: *

      nest("locale", {
        nest("format", {
          ensure("currency", (..) => panic(
            "locale::format::currency is not provided",
          ))
          ensure("date", (..) => panic("locale::date is not provided"))
        })
      })

      nest("global", {
        nest("total", {
          ensure("gross", 0)
        })
      })
    }),
    measure: (ctx, _) => {
      let total = ctx.global.total
      let prepaid = total.at("prepaid", default: 0)
      let amount = total.at("due", default: total.gross)
      let pay-str = ctx.locale.strings.payment
      let format = ctx.locale.format
      let data = (
        days: days,
        date: date,
        total: amount, // v1: the payable amount (decimal)
        // v2: what the sentence names; "amount-due" once prepayments reduce the total
        amount: (value: amount, text: [#(format.currency)(amount)]),
        amount-kind: if prepaid != 0 { "amount-due" } else { "total" },
        deadline: if date != none {
          (pay-str.deadline-date)(if type(date) == datetime {
            (format.date)(date)
          } else { date })
        } else if days != none { (pay-str.deadline-days)(days) } else {
          pay-str.deadline-soon
        },
      )

      (data, data)
    },
    draw: (ctx, _, view, ..) => call-part(ctx, "payment-terms", view),
    none,
  )
}
