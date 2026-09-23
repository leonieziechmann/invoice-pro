#import "../loom-wrapper.typ": loom, managed-motif
#import "../utils/types.typ"
#import "../utils/coercion.typ"
#import "../logic/document-type.typ": sender-pays

/// Displays the payment deadline and terms for the invoice.
///
/// -> content
#let payment-goal(
  /// The number of days allowed for payment from the invoice date.
  /// -> none | int
  days: none,

  /// A specific fixed date for the payment deadline.
  /// -> none | datetime | string | content
  date: none,
) = {
  types.require(days, "payment-goal::days", none, int)
  types.require(date, "payment-goal::date", none, datetime, str, content)

  managed-motif(
    "payment-goal",
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

      nest("theme", {
        ensure("payment-goal", (..) => panic(
          "theme::payment-goal is not provided",
        ))
      })

      nest("global", {
        nest("total", {
          ensure("gross", 0)
          ensure("prepaid", 0)
        })
      })
    }),
    measure: (ctx, _) => {
      let data = (
        days: days,
        date: date,
        total: ctx.global.total.at("due", default: ctx.global.total.gross),
        // Prepayments reduce the payable amount, so `total` is the remaining
        // amount due rather than the gross total.
        has-prepayments: ctx.global.total.prepaid > 0,
      )

      (data, data)
    },
    draw: (ctx, _, view, ..) => {
      // On a credit note or a self-billed invoice, the sender pays the
      // amount to the recipient. The layout prints the payment sentence of
      // the language (`text`, or `text-due` with prepayments), so that is
      // the sentence of this direction here.
      let ctx = ctx
      if sender-pays(ctx.at("document-type", default: none)) {
        let strings = ctx.locale.strings.payment
        ctx.locale.strings.payment = (
          strings
            + (
              text: strings.text-credit,
              text-due: strings.text-credit,
              deadline-soon: strings.deadline-soon-credit,
            )
        )
      }
      (ctx.theme.payment-goal)(ctx, view)
    },
    none,
  )
}
