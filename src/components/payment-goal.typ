#import "../loom-wrapper.typ": loom, managed-motif
#import "../utils/types.typ"
#import "../utils/coercion.typ"
#import "../logic/cash-discount.typ"
#import "../logic/document-type.typ": sender-pays
#import "../logic/payment-means.typ": goal-strings, of-context

/// Displays the payment deadline and terms.
///
/// -> content
#let payment-goal(
  /// The days allowed for payment, from the invoice date.
  /// -> none | int
  days: none,

  /// A fixed date for the payment deadline.
  /// -> none | datetime | string | content
  date: none,

  /// A cash discount (Skonto), e.g. `(days: 14, percent: 2%)`, or several.
  /// -> none | dictionary | array
  discount: none,
) = {
  types.require(days, "payment-goal::days", none, int)
  types.require(date, "payment-goal::date", none, datetime, str, content)
  types.require-day(date, "payment-goal::date")
  types.require(discount, "payment-goal::discount", none, dictionary, array)
  let discounts = cash-discount.normalize(discount)

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
      // Its notes would state the discount in the wrong direction.
      if (
        discounts.len() > 0
          and sender-pays(ctx.at("document-type", default: none))
      ) {
        panic(
          "payment-goal: a cash discount (`discount`) is not supported on a credit note or a self-billed invoice, whose sender pays the amount. Remove `discount`.",
        )
      }
      let means = of-context(ctx)
      let data = (
        days: days,
        date: date,
        total: ctx.global.total.at("due", default: ctx.global.total.gross),
        has-prepayments: ctx.global.total.prepaid > 0,
        // "direct-debit", "card", "transfer" or `none`.
        payment-means: if means != none { means.kinds.first(default: none) },
        discounts: if discounts.len() > 0 {
          cash-discount.with-notes(discounts, ctx.locale)
        } else { () },
      )

      (data, data)
    },
    draw: (ctx, _, view, ..) => {
      // The layout prints `text` or `text-due`, so they get the sentence here.
      let ctx = ctx
      let strings = ctx.locale.strings.payment
      ctx.locale.strings.payment = if sender-pays(
        ctx.at("document-type", default: none),
      ) {
        (
          strings
            + (
              text: strings.text-credit,
              text-due: strings.text-credit,
              deadline-soon: strings.deadline-soon-credit,
            )
        )
      } else {
        goal-strings(
          strings,
          of-context(ctx),
          discount-notes: view.discounts.map(step => step.note),
        )
      }
      (ctx.theme.payment-goal)(ctx, view)
    },
    none,
  )
}
